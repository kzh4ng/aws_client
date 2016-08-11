//
//  Flask.swift
//  Client2
//
//  Created by Kevin Zhang on 8/10/16.
//  Copyright © 2016 Kevin Zhang. All rights reserved.
//

import Foundation

class Flask  {

    var predictions: [Double] = []
    var numberOfDays = 2
    var flaskString: NSString = ""
    var startTime: [String:String] = [:]
    var flaskModel: Bool = false        //true sets the prediction model to flask, false gives it to AWS
    
    func predict() -> [Double]{
        let url = String(format: "http://localhost:5000/success/%@/%@/%@/%X", startTime["HR"]!, startTime["DAY_OF_YEAR"]!,startTime["WEEK_DAY"]!,numberOfDays)
        let request = NSMutableURLRequest(URL: NSURL(string: url)!)
        request.HTTPMethod = "GET"
        let config: NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.requestCachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData
        let t = NSURLSession.init(configuration: config)
        let task = t.dataTaskWithRequest(request) { data, response, error in
            guard error == nil && data != nil else {                                                          // check for fundamental networking error
                print("error!!!!!!=\(error)")
                return
            }
            
            if let httpStatus = response as? NSHTTPURLResponse where httpStatus.statusCode != 200 {           // check for http errors
                print("statusCode should be 200, but is!!!!!! \(httpStatus.statusCode)")
                print("response !!!!!!= \(response)")
            }
            
            let responseString = NSString(data: data!, encoding: NSUTF8StringEncoding)
            self.flaskString = responseString!
            let json = responseString?.parseJSONString
            for index in 0...self.numberOfDays*24-1{
                var item = json![index] as? [String:AnyObject]
                let value = item!["prediction"]! as? Double
                self.predictions.append(value!)
            }
            
            print("this is the parsed json \(self.predictions[0])")
            print("responseString !!!!!!= \(responseString!)")
        }
        task.resume()
        return predictions
    }
    
}