//
//  ViewController.swift
//  Client2
//
//  Created by Kevin Zhang on 6/27/16.
//  Copyright © 2016 Kevin Zhang. All rights reserved.
//

import UIKit
import Charts
import AWSMachineLearning

class ViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    //MARK: Properties
    
    @IBOutlet weak var dayPicker: UIPickerView!         //tag #1
    @IBOutlet weak var stationPicker: UIPickerView!     //tag #2
    @IBOutlet weak var DatePicker: UIDatePicker!        //tag #0
    @IBOutlet weak var BarChart: BarChartView!
    @IBOutlet weak var ModePicker: UISegmentedControl!
    
    //AWS ML Client
    var MachineLearning: AWSMachineLearning?
    
    //Caching endpoint
    var endpoint: String?
    
    var inputs: [[String:String]] = []                  //array of all inputs
    var newInputs: [[String:String]] = []               //array of inputs that need predictions, (if the user wants more
    var predictionsAWS: [Double] = []
    var predictionsFlask: [Double] = []
    var dayPickerDataSource = [Int]()
    var stationPickerDataSource = ["01A", "01B"]
    var numberOfDays = 1
    var stationValue: String = "01A" //default value, row 0 in the pickerView
    var startDate: NSDate = NSDate()
    var flaskModel: Bool = false        //true sets the prediction model to flask, false gives it to AWS
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DatePicker.minimumDate = NSDate(dateString:"2010-01-01")
        DatePicker.maximumDate = NSDate(dateString:"2020-12-31")
        dayPicker.dataSource = self
        dayPicker.delegate = self
        stationPicker.delegate = self
        stationPicker.dataSource = self
        
        dayPickerDataSource += 1...14
        
        refreshAllPredictions()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //MARK: PickerView
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView.tag == 1 {
            return dayPickerDataSource.count;
        }
        else {
            return stationPickerDataSource.count
        }
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView.tag == 1 {
            return String(dayPickerDataSource[row])
        }
        else {
            return stationPickerDataSource[row]
        }
    }
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int)
    {
        numberOfDays = dayPickerDataSource[row]
        if flaskModel{
            startDate = DatePicker.date
            query()
            
        }
        else{
            if pickerView.tag == 1 {        //number of days
                numberOfDays = dayPickerDataSource[row]
                if startDate == DatePicker.date {           //date in picker is unchanged
                    let previousDayValue = predictionsAWS.count/24
                    addPredictions(previousDayValue, newDaysAmount: numberOfDays)
                }
                else {
                    startDate = DatePicker.date
                    refreshAllPredictions()
                }
                
            }
            else {                          //station picker
                startDate = DatePicker.date
                stationValue = stationPickerDataSource[row]
                refreshAllPredictions()
            }
        }
        
    }
    
    //MARK: UISegmentedControl
    
    @IBAction func ModeChange(sender: UISegmentedControl) {
        switch ModePicker.selectedSegmentIndex {
        case 0:
            flaskModel = false
            refreshAllPredictions()
        case 1:
            flaskModel = true
            flask()
        default:
            break
        }
    }
    
    //MARK: Flask
    
    //Ignores any local caching and sends a GET request, parses JSON array and stores predictions in predictionsFlask
    func flask(){
        let startTime = inputs[0] as [String:String]
        let url = String(format: "http://wimnow.com:5001/success/%@/%@/%@/%X", startTime["HR"]!, startTime["DAY_OF_YEAR"]!,startTime["WEEK_DAY"]!,numberOfDays)
        let request = NSMutableURLRequest(URL: NSURL(string: url)!)
        request.HTTPMethod = "GET"
        let config: NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.requestCachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData
        let t = NSURLSession.init(configuration: config)
        let task = t.dataTaskWithRequest(request) { data, response, error in
            guard error == nil && data != nil else {                                                          // check for fundamental networking error
                print("error! = \(error)")
                return
            }
            
            if let httpStatus = response as? NSHTTPURLResponse where httpStatus.statusCode != 200 {           // check for http errors
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print("response = \(response)")
            }
            
            let responseString = NSString(data: data!, encoding: NSUTF8StringEncoding)
            let json = responseString?.parseJSONString
            for index in 0...self.numberOfDays*24-1{
                var item = json![index] as? [String:AnyObject]
                let value = item!["prediction"]! as? Double
                self.predictionsFlask.append(value!)
            }
            self.populateChart()
        }
        task.resume()
    }
    
    func query(){
        inputs = []
        predictionsFlask = []
        generateInputs(nil, amount: nil)
        flask()
    }
    
    //MARK: AWS Machine Learning
    
    //generate all new predictions because starting date is changed
    func refreshAllPredictions() {
        
        inputs = []
        predictionsAWS = []
        generateInputs(nil, amount: nil)
        fetchPredictions(inputs)
    }
    
    //keep existing predictions or delete some predictions based on # of days, starting date is not changed
    func addPredictions(previousDaysAmount: Int, newDaysAmount: Int) {
        
        let size = inputs.count
        let lastIndex = newDaysAmount*24
        if newDaysAmount < previousDaysAmount {     //if less days are needed
            for _ in lastIndex ... size - 1 {
                inputs.removeAtIndex(lastIndex)
                predictionsAWS.removeAtIndex(lastIndex)
                self.populateChart()
            }
        }
        else if newDaysAmount == previousDaysAmount {   //if days amount is unchanged
            self.populateChart()
        }
        else {                                          //if we want more days
            generateInputs(startDate.dateByAddingTimeInterval(86400*Double(previousDaysAmount)), amount: newDaysAmount-previousDaysAmount)
            fetchPredictions(newInputs)
        }
    }

    //establishes safe connection with AWS model and appends predictions to predictionsAWS, fetches predictions for whole 'input' array
    func fetchPredictions(input: [[String:String]]) {
        MachineLearning = AWSMachineLearning.defaultMachineLearning()
        let getMLModelInput  = AWSMachineLearningGetMLModelInput()
        let model_id = Config.modelID
        getMLModelInput.MLModelId = model_id
        
        MachineLearning!.getMLModel(getMLModelInput).continueWithSuccessBlock { (task) -> AnyObject? in
            let getOutput: AWSMachineLearningGetMLModelOutput = task.result as! AWSMachineLearningGetMLModelOutput
            if(getOutput.status != AWSMachineLearningEntityStatus.Completed) {
                NSLog("Model not completed")
                return nil
            }
            else if(getOutput.endpointInfo?.endpointStatus != AWSMachineLearningRealtimeEndpointStatus.Ready) {
                NSLog("Endpoint is not ready")
                return nil
            }
            else {
                self.endpoint = getOutput.endpointInfo?.endpointUrl
                var tasks: [AWSTask] = [AWSTask]()
                for entry in input {
                    tasks.append(self.predict(model_id, record: entry).continueWithSuccessBlock {(t) -> AnyObject? in
                        let prediction: AWSMachineLearningPredictOutput = t.result as! AWSMachineLearningPredictOutput
                        let predictedVolume = prediction.prediction?.predictedValue as! Double
                        
                        print(prediction.prediction?.predictedValue)
                        
                        //add prediction to cached array
                        self.predictionsAWS.append(predictedVolume.roundToPlaces(4))
                        return nil
                        })
                }
                AWSTask.init(forCompletionOfAllTasks: tasks).continueWithSuccessBlock({(task: AWSTask) -> AnyObject? in
                    self.populateChart()
                    return nil
                })
                
            }
            return nil
        }
    }
    
    func predict(mlModelId: String, record: [String: String]) -> AWSTask {
        let predictInput: AWSMachineLearningPredictInput = AWSMachineLearningPredictInput()
        predictInput.predictEndpoint = endpoint
        predictInput.MLModelId = mlModelId
        predictInput.record = record
        return MachineLearning!.predict(predictInput)
    }
    
    //@param: starting day from which to generate inputs, and the number of days for which to generate inputs
    //by default generates inputs for the whole 'inputs' array specified by 'numberOfDays'
    func generateInputs(start: NSDate?, amount: Int?){
        var currentDate: NSDate
        var timeframe: Int
        let cal = NSCalendar.currentCalendar()
        self.newInputs = []
        
        if start != nil && amount != nil {
            currentDate = start!
            timeframe = amount!
        }
        else {
            currentDate = startDate
            timeframe = numberOfDays
        }
        var hour = 0
        
        //insert inputs for each hour
        for _ in 1...timeframe*24 {
            let hourField = String(hour)
            let doy = cal.ordinalityOfUnit(.Day, inUnit: .Year, forDate: currentDate)
            let dayOfWeek = String(currentDate.dayOfWeek())
            let dict:[String:String] = [
                "HR" : hourField,
                "WEEK_DAY" : dayOfWeek,
                "DAY_OF_YEAR" : String(doy)
            ]
            
            inputs.append(dict)
            newInputs.append(dict)
            
            //reset hour to zero and change date to tomorrow
            if hour == 23 {
                currentDate = currentDate.tomorrow()
            }
            hour = (hour+1)%23

        }
    }
    
    //MARK: Bar Chart
    
    //displays traffic volumes from either predictionsFlask or predictionsAWS
    func populateChart(){
        
        var chartVolumeData = [ChartDataEntry]()
        var times = [String]()
        
        
        if flaskModel {
            precondition(predictionsFlask.count >= inputs.count)
            for index in 0...inputs.count-1 {
                times.append(inputs[index]["HR"]!)
                chartVolumeData.append(BarChartDataEntry(value: predictionsFlask[index], xIndex: index))
            }
        }
        else {
            for index in 0...inputs.count-1 {
                times.append(inputs[index]["HR"]!)
                chartVolumeData.append(BarChartDataEntry(value: predictionsAWS[index], xIndex: index))
            }
        }
        
        
        let chartDataSet = BarChartDataSet(yVals: chartVolumeData, label: "Volume")
        let chartData = BarChartData(xVals: times, dataSets: [chartDataSet])
        
        BarChart.data = chartData
        BarChart.xAxis.labelPosition = .Top
        BarChart.descriptionText = ""
        BarChart.legend.enabled = false
        BarChart.animate(yAxisDuration: 1.5, easingOption: .EaseInOutQuart)
    }
}