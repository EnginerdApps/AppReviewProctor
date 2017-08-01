//
//  ViewController.swift
//
//  Provides an example of how to use AppReviewProctor.

//  Copyright © 2017 Enginerd, LLC. All rights reserved. http://www.enginerdapps.com
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit
import AppReviewProctor

class ViewController: UIViewController {

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Create a UIButton to illustrate direct, non-proctored review requests
        let review_button = UIButton(frame: CGRect(x: 10, y: 60, width: 125, height: 30))
        review_button.setTitle("Direct Review", for: .normal)
        review_button.setTitleColor(UIColor.red, for: .normal)
        review_button.addTarget(self, action: #selector(performDirectReview), for: .touchUpInside)
        view.addSubview(review_button)
        
        // Optional setter function to tell AppReviewProctor how many times the user must
        // use the app before a review is displayed (potentially, since SKStoreReviewController
        // will have its own additional restrictions)
        AppReviewProctor.setUsesThreshold(0)
        
        // Optional setter function to tell AppReviewProctor how many "significant events" the 
        // user must perform before a review is displayed (potentially, since SKStoreReviewController
        // will have its own additional restrictions).  A "significant event" can be any operation
        // performed within your app that you determine contributes significantly to the user 
        // experience, such as completing a game level or saving a file, etc.
        AppReviewProctor.setSignificantEventsThreshold(1)
        
        // Throughout your app you can specify where "significant events" occur, and after a
        // threshold number of those events take place, this condition will be met.
        AppReviewProctor.addSignificantEvent()
        
    }

    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        
        // Requests a proctored review, which will only happen if the default or
        // developer-specified conditions have been met.
        AppReviewProctor.requestProctoredReview(handler: { (displayed, error) -> Void in
            NSLog("App Review Proctor: Finished (\(displayed), \(error?.description))")
        })

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func performDirectReview() {

        // This will request a direct review that is not proctored.  That is, no prior
        // conditions will be checked and the review will be shown.  The only prevention
        // for displaying the review will happen by any app store policy considerations
        // by SKStoreReviewController.
        AppReviewProctor.requestDirectReview()
        
    }
    
}

