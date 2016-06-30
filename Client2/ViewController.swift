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
    
    //AWS ML Client
    var MachineLearning: AWSMachineLearning?
    
    //Caching endpoint
    var endpoint: String?
    
    var inputs: [[String:String]] = []
    var predictedVolumes: [Double] = []
    var dayPickerDataSource = [Int]()
    var stationPickerDataSource = ["01A", "01B"]
    var numberOfDays = 1
    var stationValue: String = "01A" //default value, row 0 in the pickerView
    var date: NSDate = NSDate()
    var graphDisplayed: Bool = false
    
    var GlobalMainQueue: dispatch_queue_t {
        return dispatch_get_main_queue()
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        DatePicker.minimumDate = NSDate(dateString:"2010-01-01")
        DatePicker.maximumDate = NSDate(dateString:"2020-12-31")
        dayPicker.dataSource = self
        dayPicker.delegate = self
        stationPicker.delegate = self
        stationPicker.dataSource = self
        
        dayPickerDataSource += 1...14
        
        refreshPredictions()
        

        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
        if pickerView.tag == 1 {        //number of days
            numberOfDays = dayPickerDataSource[row]

        }
        else if pickerView.tag == 2 {   //station picker
            stationValue = stationPickerDataSource[row]
        }
        else {                          //date picker
            date = DatePicker.date
        }
        
        refreshPredictions()
    }
    
    //MARK: Bar Chart
    
    func populateChart(){
        
        var chartVolumeData = [ChartDataEntry]()
        var times = [String]()
        precondition(predictedVolumes.count >= inputs.count)
        for index in 0...inputs.count-1 {
            times.append(inputs[index]["HR"]!)
            chartVolumeData.append(BarChartDataEntry(value: predictedVolumes[index], xIndex: index))
        }
        
        let chartDataSet = BarChartDataSet(yVals: chartVolumeData, label: "Volume")
        let chartData = BarChartData(xVals: times, dataSets: [chartDataSet])
        
        BarChart.data = chartData
        BarChart.descriptionText = ""
        chartDataSet.colors = ChartColorTemplates.vordiplom()
        BarChart.xAxis.labelPosition = .Bottom
        BarChart.legend.enabled = false
        BarChart.animate(yAxisDuration: 1.5, easingOption: .EaseInOutQuart)
        
    }
    
    
    //MARK: AWS Machine Learning
    
    func refreshPredictions() {
        inputs = []
        predictedVolumes = []
        
        generateInputs()

        if predictedVolumes.count < numberOfDays*24 { //fetch predictions for each hour
            fetchPredictions()
            print("inside")
        }
        
        while predictedVolumes.count < 24 * numberOfDays {
           // print(predictedVolumes.count)
        }
        populateChart()
        
        /*let delayInSeconds = 1.0
        let popTime = dispatch_time(DISPATCH_TIME_NOW,
                                    Int64(delayInSeconds * Double(NSEC_PER_SEC))) // 1
        dispatch_after(popTime, GlobalMainQueue) { // 2
            self.populateChart()

        }*/
    }
    
    func predict(mlModelId: String, record: [String: String]) -> AWSTask {
        let predictInput: AWSMachineLearningPredictInput = AWSMachineLearningPredictInput()
        predictInput.predictEndpoint = endpoint
        predictInput.MLModelId = mlModelId
        predictInput.record = record
        return MachineLearning!.predict(predictInput)
    }
    
    func fetchPredictions() {
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
                for input in self.inputs {
                    self.predict(model_id, record: input).continueWithSuccessBlock {(t) -> AnyObject? in
                        let prediction: AWSMachineLearningPredictOutput = t.result as! AWSMachineLearningPredictOutput
                        let predictedVolume = prediction.prediction?.predictedValue as! Double
                        
                        print(prediction.prediction?.predictedValue)
                        
                        //add prediction to cached array
                        self.predictedVolumes.append(predictedVolume.roundToPlaces(4))
                        return nil
                    }
                }
            }
            return nil
        }
    }
    
    func generateInputs(){
        var currentDate = date
        var hour = currentDate.hour()
        
        //insert inputs for each hour
        for _ in 1...numberOfDays*24 {
            var hourField = String(hour)
            //insert zero if hour < 10 for HH format
            if hour < 10 {
                hourField.insert("0", atIndex: hourField.startIndex)
            }
            let dateString = currentDate.formatDateString()
            let dayOfWeek = String(currentDate.dayOfWeek())
            
            let dict:[String:String] = [
                "HR" : hourField,
                "DT" : dateString,
                "SITE_EXT" : stationValue,
                "WEEK_DAY" : dayOfWeek
            ]
            
            inputs.append(dict)
            
            //reset hour to zero and change date to tomorrow
            if hour == 23 {
                currentDate = currentDate.tomorrow()
                hour = 0
            }
            else {
                hour += 1
            }
        }
    }

}

