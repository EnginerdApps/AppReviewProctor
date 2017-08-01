//
//  AppReviewProctor.swift
//
//  Provides bookkeeping support to decide when to ask the user whether to rate
//  an app, in addition to the app store based restrictions built in to
//  SKStoreReviewController.
//
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

import Foundation
import StoreKit

public class AppReviewProctor {
    
    // MARK: - Defaults
    
    // set your compiler flags to contain -DDebug if you want debug output
    fileprivate static var ARPDebug: Bool = false
    
    // default app bundle id
    fileprivate static var DefaultBundleID = Bundle.main.bundleIdentifier!
    
    // default app title as specified in the app bundle
    fileprivate static var DefaultAppTitle = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
    
    // default app version as specified in the app bundle
    fileprivate static var DefaultAppVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    
    // our apple affiliate code, which will be used as a default in case you do not set
    // your own.  if you are an apple affiliate, use the setting functions provided to
    // set your own affiliate code to use for your app reviews.  feel free to leave this
    // at the default value if you like using App Review Proctor and want to thank us.
    // note that this only matters for reviews performed without SKStoreReviewController,
    // as that does not appear to support affiliate codes at this point.
    fileprivate static var DefaultAffiliateCode: String = ""
    fileprivate static var DefaultAffiliateCampaignCode: String = ""
    
    // default text to display when a review is requested
    fileprivate static var  DefaultReviewText: String = "If you enjoy using this app, would you take a moment to rate it? This will help us reach others with similar interests. Thanks for your support!"
    
    // default values for the various proctoring checks.  set your own values
    // by calling the appropriate setter functions in AppDelegate.swift
    fileprivate static var DefaultSignificantEventThreshold: Int = 30
    fileprivate static var DefaultUseThreshold: Int = 10
    fileprivate static var DefaultDaysSinceInstallThreshold: Int = 10
    fileprivate static var DefaultDaysSinceLastReviewThreshold: Int = 30
    fileprivate static var DefaultReminderThreshold: Int = 1
    
    // MARK: - Public App Review Methods
    
    // Prompts the user for an app review, if appropriate.  This is done asynchronously.
    //
    // - result handler: (Bool, NSError) Called when the review display has completed. Will return the
    //                   success state if it is appropriate to display a review, and
    //                   a detailed error if not.
    public static func requestProctoredReview(handler: @escaping (Bool, NSError?) -> ()) {
        
        DispatchQueue.main.async {
            setDebugMode(true)
            proctoredReview(handler: handler)
        }
        
    }
    
    // Prompts the user directly for an app review, with no proctoring.  This is done
    // asynchronously.  This updates proctoring values related to the most recent
    // review date.
    //
    public static func requestDirectReview() {
        
        if ARPDebug {
            NSLog("App Review Proctor: Direct Review Requested")
        }
        
        if let app_id = getAppID() {
            
            setDebugMode(true)
            
            // add a new "last review" date
            addReviewDate()
            
            directReview(app_id)
            
        }
        
    }
    
}

// MARK: - Private App Review Methods
extension AppReviewProctor {
    
    // Implements the review proctoring steps.
    //
    // - result handler: (Bool, NSError) Called when the review display has completed. Will return the
    //                   success state if it is appropriate to display a review, and
    //                   a detailed error if not.
    fileprivate static func proctoredReview(handler: @escaping (Bool, NSError?) -> ()) {
        
        var what_went_wrong: Int = 0
        var error_details: String = String()
        
        if ARPDebug {
            NSLog("App Review Proctor: Proctored Review Requested")
        }
        
        // validate that various conditions are met.
        // NOTE: step through this code if you cannot figure out why won't display.
        if checkRefusalDate() == false {
            what_went_wrong = 1
        } else if checkReminderDate() == false {
            what_went_wrong = 2
        } else if checkDaysSinceLastReview() == false {
            what_went_wrong = 3
        } else if checkDaysSinceInstall() == false {
            what_went_wrong = 4
        } else if checkUses() == false {
            what_went_wrong = 5
        } else if checkSignificantEvents() == false {
            what_went_wrong = 6
        } else if checkAppInfo() == false {
            what_went_wrong = 7
        }
        
        if what_went_wrong == 0 {
            
            // display the actual review using the most appropriate SDK approach. this
            // will handle the user refusing a review, or delaying a review, as well.
            displayPrompt()
            
            if ARPDebug {
                NSLog("App Review Proctor: Review Request Granted")
            }
            
            // no problem, review displayed
            handler(true, nil)
            
        } else {
            
            // construct the error details, which will describe only the first
            // problem encountered
            var user_info: [AnyHashable : Any]
            switch what_went_wrong {
            case 1:
                error_details = "checkRefusalDate()"
                break
            case 2:
                error_details = "checkReminderDate()"
                break
            case 3:
                error_details = "checkDaysSinceLastReview()"
                break
            case 4:
                error_details = "checkDaysSinceInstall()"
                break
            case 5:
                error_details = "checkUses()"
                break
            case 6:
                error_details = "checkSignificantEvents()"
                break
            case 7:
                error_details = "checkAppInfo()"
                break
            default:
                error_details = "Unknown"
                break
            }
            
            user_info = [NSLocalizedDescriptionKey :  NSLocalizedString("Conditions not met", value: error_details, comment: "") , NSLocalizedFailureReasonErrorKey : NSLocalizedString("Conditions not met", value: "Conditions not met", comment: "")]
            let err = NSError(domain: "AppReviewProctorErrorDomain", code: 401, userInfo: user_info)
            
            if ARPDebug {
                NSLog("App Review Proctor: Review Request Denied")
            }
            
            // conditions not met, review not displayed
            handler(false, err)
            
        }
        
    }
    
    // Takes the user directly to the app store review page without proctoring.
    //
    // - (param) id: (String) The app store id of the app to review
    //
    fileprivate static func directReview(_ id: String?) {
        
        guard let id = id else { return }
        
        let affiliate_code: String = getAffiliateCode()
        let affiliate_campaign_code: String = getAffiliateCampaignCode()
        
        // NOTE: the iTunes URL protocol (itms-apps://) doesn't work in the simulator.
        let formatted_url = "itms-apps://itunes.apple.com/app/id\(id)&at=\(affiliate_code)&ct=\(affiliate_campaign_code)?action=write-review"
        //let formatted_url = "itms-apps://itunes.apple.com/app/id\(id)?action=write-review"
        
        if let url = URL(string: formatted_url) {
            if #available(iOS 10, *) {
                UIApplication.shared.open(url, options: [:], completionHandler: { (success) in
                    if ARPDebug {
                        NSLog("App Review Proctor: Open Direct Review (\(success)) [url = \(url)]")
                    }
                })
            } else {
                let success = UIApplication.shared.openURL(url)
                if ARPDebug {
                    NSLog("App Review Proctor: Open Direct Review (\(success)) [url = \(url)]")
                }
            }
        }
        
    }
    
}

// MARK: - Add Event Methods
extension AppReviewProctor {
    
    // Add a "significant event" to track the user's use of the app features to be
    // reviewed.
    //
    public static func addSignificantEvent() {
        
        var event_count: Int = 0
        let user_defaults = UserDefaults.standard as UserDefaults
        
        if let event_count_check: Int = user_defaults.value(forKey: "\(DefaultBundleID)ARPEvents") as? Int {
            event_count = event_count_check
        } else {
            event_count = 0
        }
        
        event_count += 1
        
        user_defaults.set(event_count, forKey: "\(DefaultBundleID)ARPEvents")
        user_defaults.synchronize()
        
        if ARPDebug {
            NSLog("App Review Proctor: addSignificantEvent() count = \(event_count)")
        }
        
    }
    
    // Add a "use" to track the user's use of the app to be reviewed.
    //
    public static func addUse() {
        
        var use_count: Int = 0
        let user_defaults = UserDefaults.standard as UserDefaults
        
        if let use_count_check: Int = user_defaults.value(forKey: "\(DefaultBundleID)ARPUses") as? Int {
            use_count = use_count_check
        } else {
            use_count = 0
        }
        
        use_count += 1
        
        user_defaults.set(use_count, forKey: "\(DefaultBundleID)ARPUses")
        user_defaults.synchronize()
        
        if ARPDebug {
            NSLog("App Review Proctor: addUse() count = \(use_count)")
        }
        
    }
    
    // Add the date the app was installed, to track how long the user has been using the
    // app to be reviewed.  If an install date exists already, this will not overwrite
    // it with a later date.
    //
    fileprivate static func addInstallDate() {
        
        let user_defaults = UserDefaults.standard as UserDefaults
        
        if let _: Date = user_defaults.value(forKey: "\(DefaultBundleID)ARPInstall") as? Date {
            
            if ARPDebug {
                NSLog("App Review Proctor: addInstallDate() -> \("Install Date Already Exists")")
            }
            
        } else {
            
            let current_date: Date = Date()
            
            user_defaults.set(current_date, forKey: "\(DefaultBundleID)ARPInstall")
            user_defaults.synchronize()
            
            if ARPDebug {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                let date_string = formatter.string(from: current_date)
                NSLog("App Review Proctor: addInstallDate() -> \(date_string)")
            }
            
        }
        
    }
    
    // Add a review date, so that a subsequent review is not prompted too soon after a
    // previous review request.
    //
    fileprivate static func addReviewDate() {
        
        let current_date: Date = Date()
        let user_defaults = UserDefaults.standard as UserDefaults
        
        user_defaults.set(current_date, forKey: "\(DefaultBundleID)ARPReview")
        user_defaults.synchronize()
        
        if ARPDebug {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            let date_string = formatter.string(from: current_date)
            NSLog("App Review Proctor: addReviewDate() -> \(date_string)")
        }
        
    }
    
    // Add a refusal date, so that we can halt prompting for the near future.
    //
    fileprivate static func addRefusalDate() {
        
        let current_date: Date = Date()
        let user_defaults = UserDefaults.standard as UserDefaults
        
        user_defaults.set(current_date, forKey: "\(DefaultBundleID)ARPRefusal")
        user_defaults.synchronize()
        
        if ARPDebug {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            let date_string = formatter.string(from: current_date)
            NSLog("App Review Proctor: addRefusalDate() -> \(date_string)")
        }
        
    }
    
    // Add a "remind me later" date, so that we can remind the user to
    // review in the near future.
    //
    fileprivate static func addReminderDate() {
        
        let current_date: Date = Date()
        let user_defaults = UserDefaults.standard as UserDefaults
        
        user_defaults.set(current_date, forKey: "\(DefaultBundleID)ARPReminder")
        user_defaults.synchronize()
        
        if ARPDebug {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            let date_string = formatter.string(from: current_date)
            NSLog("App Review Proctor: addReminderDate() -> \(date_string)")
        }
        
    }
    
}

// MARK: - Setup Condition Threshold Methods
extension AppReviewProctor {
    
    // Set the number of significant events that must occur before a review is allowed.
    //
    // - (param) threshold: (Int) the number to set as the "significant event" threshold
    //
    public static func setSignificantEventsThreshold(_ threshold: Int?) {
        
        guard let threshold = threshold else { return }
        
        if ARPDebug {
            NSLog("App Review Proctor: setSignificantEventsThreshold(\(threshold))")
        }
        
        let user_defaults = UserDefaults.standard as UserDefaults
        user_defaults.set(threshold, forKey: "\(DefaultBundleID)ARPEventsThreshold")
        user_defaults.synchronize()
        
    }
    
    // Set the number of app uses that must occur before a review is allowed.
    //
    // - (param) threshold: (Int) the number to set as the "app use" threshold
    //
    public static func setUsesThreshold(_ threshold: Int?) {
        
        guard let threshold = threshold else { return }
        
        if ARPDebug {
            NSLog("App Review Proctor: setUsesThreshold(\(threshold))")
        }
        
        let user_defaults = UserDefaults.standard as UserDefaults
        user_defaults.set(threshold, forKey: "\(DefaultBundleID)ARPUsesThreshold")
        user_defaults.synchronize()
        
    }
    
    // Set the number of days that must pass after the app is installed before a
    // review is allowed.
    //
    // - (param) threshold: (Int) the number to set as the "days since install" threshold
    //
    public static func setDaysSinceInstallThreshold(_ threshold: Int?) {
        
        guard let threshold = threshold else { return }
        
        if ARPDebug {
            NSLog("App Review Proctor: setDaysSinceInstallThreshold(\(threshold))")
        }
        
        let user_defaults = UserDefaults.standard as UserDefaults
        user_defaults.set(threshold, forKey: "\(DefaultBundleID)ARPInstallThreshold")
        user_defaults.synchronize()
        
    }
    
    // Set the number of days that must pass after the previous app review before a
    // subsequent review is allowed.
    //
    // - (param) threshold: (Int) the number to set as the "days since review" threshold
    //
    public static func setDaysSinceLastReviewThreshold(_ threshold: Int?) {
        
        guard let threshold = threshold else { return }
        
        if ARPDebug {
            NSLog("App Review Proctor: setDaysSinceLastReviewThreshold(\(threshold))")
        }
        
        let user_defaults = UserDefaults.standard as UserDefaults
        user_defaults.set(threshold, forKey: "\(DefaultBundleID)ARPReviewThreshold")
        user_defaults.synchronize()
        
    }
    
    // Set the number of days to wait until a review is prompted again after the user
    // selects "remind me later."
    //
    // - (param) threshold: (Int) the number to wait after "remind me later" is selected
    //
    public static func setReminderThreshold(_ threshold: Int?) {
        
        guard let threshold = threshold else { return }
        
        if ARPDebug {
            NSLog("App Review Proctor: setReminderThreshold(\(threshold))")
        }
        
        let user_defaults = UserDefaults.standard as UserDefaults
        user_defaults.set(threshold, forKey: "\(DefaultBundleID)ARPReminderThreshold")
        user_defaults.synchronize()
        
    }
    
}

// MARK: - Check Condition Methods
extension AppReviewProctor {
    
    // Check if enough time has passed since a review request was refused.  By default
    // this time period is 4 months (91 days roughly), and is not configurable as a refusal is hard
    // evidence that the user does not want to be bothered with a review in the
    // near future.
    //
    fileprivate static func checkRefusalDate() -> Bool {
        
        var refusal_date: Date
        
        let user_defaults = UserDefaults.standard as UserDefaults
        
        // get the date the user refused to review
        if let refusal_date_check: Date = user_defaults.value(forKey: "\(DefaultBundleID)ARPRefusal") as? Date {
            refusal_date = refusal_date_check
        } else {
            return true // no refusal date was recorded, so this check passes
        }
        
        let elapsed_seconds = Date().timeIntervalSince(refusal_date)
        let elapsed_days = Int(floor(elapsed_seconds / 86400))
        
        if ARPDebug {
            NSLog("App Review Proctor: checkRefusalDate() days = \(elapsed_days)")
        }
        
        // proctor check is met if total is greater than or equal to the threshold
        if elapsed_days >= 91 {
            if ARPDebug {
                NSLog("App Review Proctor: checkRefusalDate() -> true")
            }
            return true
        } else {
            if ARPDebug {
                NSLog("App Review Proctor: checkRefusalDate() -> false")
            }
            return false
        }
        
    }
    
    // If a user selects "remind me later" we want to wait a certain number of
    // days and prompt again.  By default this is set to 1 day, but can be
    // modified with setReminderThreshold().
    //
    fileprivate static func checkReminderDate() -> Bool {
        
        var reminder_date: Date
        var reminder_threshold: Int = 0
        
        let user_defaults = UserDefaults.standard as UserDefaults
        
        // get the date the user selected "remind me later"
        if let reminder_date_check: Date = user_defaults.value(forKey: "\(DefaultBundleID)ARPReminder") as? Date {
            reminder_date = reminder_date_check
        } else {
            return true // no "remind me later" date was recorded, so this check passes
        }
        
        // get the "remind me later" waiting time threshold
        if let reminder_threshold_check: Int = user_defaults.value(forKey: "\(DefaultBundleID)ARPReminderThreshold") as? Int {
            reminder_threshold = reminder_threshold_check
        } else {
            reminder_threshold = DefaultReminderThreshold
        }
        
        let elapsed_seconds = Date().timeIntervalSince(reminder_date)
        let elapsed_days = Int(floor(elapsed_seconds / 86400))
        
        if ARPDebug {
            NSLog("App Review Proctor: checkReminderDate() days = \(elapsed_days)")
        }
        
        // proctor check is met if total is greater than or equal to the threshold
        if elapsed_days >= reminder_threshold {
            if ARPDebug {
                NSLog("App Review Proctor: checkReminderDate() -> true")
            }
            return true
        } else {
            if ARPDebug {
                NSLog("App Review Proctor: checkReminderDate() -> false")
            }
            return false
        }
        
    }
    
    // Check if the number of significant events has met the threshold to allow an
    // app review.
    //
    fileprivate static func checkSignificantEvents() -> Bool {
        
        var events_total: Int = 0
        var events_threshold: Int = 0
        
        let user_defaults = UserDefaults.standard as UserDefaults
        
        // get the current number of significant events
        if let events_total_check: Int = user_defaults.value(forKey: "\(DefaultBundleID)ARPEvents") as? Int {
            events_total = events_total_check
        } else {
            events_total = 0
        }
        
        // get the significant events threshold
        if let events_threshold_check: Int = user_defaults.value(forKey: "\(DefaultBundleID)ARPEventsThreshold") as? Int {
            events_threshold = events_threshold_check
        } else {
            events_threshold = DefaultSignificantEventThreshold
        }
        
        if ARPDebug {
            NSLog("App Review Proctor: checkSignificantEvents() value = \(events_total)")
        }
        
        // proctor check is met if total is greater than or equal to the threshold
        // wouldn't it be nice if swift would let us return (total >= threshold) ? true : false
        if events_total >= events_threshold {
            if ARPDebug {
                NSLog("App Review Proctor: checkSignificantEvents() -> true")
            }
            return true
        } else {
            if ARPDebug {
                NSLog("App Review Proctor: checkSignificantEvents() -> false")
            }
            return false
        }
        
    }
    
    // Check if the number of app uses has met the threshold to allow a review.
    //
    fileprivate static func checkUses() -> Bool {
        
        var uses_total: Int = 0
        var uses_threshold: Int = 0
        
        let user_defaults = UserDefaults.standard as UserDefaults
        
        // get the current number of app uses
        if let uses_total_check: Int = user_defaults.value(forKey: "\(DefaultBundleID)ARPUses") as? Int {
            uses_total = uses_total_check
        } else {
            uses_total = 0
        }
        
        // get the app uses threshold
        if let uses_threshold_check: Int = user_defaults.value(forKey: "\(DefaultBundleID)ARPUsesThreshold") as? Int {
            uses_threshold = uses_threshold_check
        } else {
            uses_threshold = DefaultUseThreshold
        }
        
        if ARPDebug {
            NSLog("App Review Proctor: checkUses() value = \(uses_total)")
        }
        
        // proctor check is met if total is greater than or equal to the threshold
        // wouldn't it be nice if swift would let us return (total >= threshold) ? true : false
        if uses_total >= uses_threshold {
            if ARPDebug {
                NSLog("App Review Proctor: checkUses() -> true")
            }
            return true
        } else {
            if ARPDebug {
                NSLog("App Review Proctor: checkUses() -> false")
            }
            return false
        }
        
    }
    
    // Check if at least the threshold number of days has passed since the app was
    // installed.
    //
    fileprivate static func checkDaysSinceInstall() -> Bool {
        
        var install_date: Date
        var days_threshold: Int = 0
        
        let user_defaults = UserDefaults.standard as UserDefaults
        
        // get the app install date
        if let install_date_check: Date = user_defaults.value(forKey: "\(DefaultBundleID)ARPInstall") as? Date {
            install_date = install_date_check
        } else {
            return false // no install date was recorded, so this check fails
        }
        
        // get the "days since install" threshold
        if let days_threshold_check: Int = user_defaults.value(forKey: "\(DefaultBundleID)ARPInstallThreshold") as? Int {
            days_threshold = days_threshold_check
        } else {
            days_threshold = DefaultDaysSinceInstallThreshold
        }
        
        let elapsed_seconds = Date().timeIntervalSince(install_date)
        let elapsed_days = Int(floor(elapsed_seconds / 86400))
        
        if ARPDebug {
            NSLog("App Review Proctor: checkDaysSinceInstall() days = \(elapsed_days)")
        }
        
        // proctor check is met if total is greater than or equal to the threshold
        if elapsed_days >= days_threshold {
            if ARPDebug {
                NSLog("App Review Proctor: checkDaysSinceInstall() -> true")
            }
            return true
        } else {
            if ARPDebug {
                NSLog("App Review Proctor: checkDaysSinceInstall() -> false")
            }
            return false
        }
        
    }
    
    // Check if at least the threshold number of days has passed since the app was
    // last reviewed.
    //
    fileprivate static func checkDaysSinceLastReview() -> Bool {
        
        var review_date: Date
        var days_threshold: Int = 0
        
        let user_defaults = UserDefaults.standard as UserDefaults
        
        // get the previous review date
        if let review_date_check: Date = user_defaults.value(forKey: "\(DefaultBundleID)ARPReview") as? Date {
            review_date = review_date_check
        } else {
            return true // no previous review has taken place, so this check has been met
        }
        
        // get the "days since last review" threshold
        if let days_threshold_check: Int = user_defaults.value(forKey: "\(DefaultBundleID)ARPReviewThreshold") as? Int {
            days_threshold = days_threshold_check
        } else {
            days_threshold = DefaultDaysSinceLastReviewThreshold
        }
        
        let elapsed_seconds = Date().timeIntervalSince(review_date)
        let elapsed_days = Int(floor(elapsed_seconds / 86400))
        
        if ARPDebug {
            NSLog("App Review Proctor: checkDaysSinceLastReview() days = \(elapsed_days)")
        }
        
        // proctor check is met if total is greater than or equal to the threshold
        if elapsed_days >= days_threshold {
            if ARPDebug {
                NSLog("App Review Proctor: checkDaysSinceLastReview() -> true")
            }
            return true
        } else {
            if ARPDebug {
                NSLog("App Review Proctor: checkDaysSinceLastReview() -> false")
            }
            return false
        }
        
    }
    
    // If SKStoreReviewController is not available or used, certain app information
    // must be set before a review prompt can be shown, because we won't have
    // the apple sdk handling which information to show in a review request (such
    // as the app name, version, description, link to store, etc). As a result,
    // we have to fail if the most basic of this information (such as the app store
    // link) has not been set, since a user can still be using older iOS versions
    // that will not support SKStoreReviewController.
    //
    fileprivate static func checkAppInfo() -> Bool {
        
        if #available(iOS 10.3, *) {
            
            if ARPDebug {
                NSLog("App Review Proctor: checkAppInfo() -> true")
            }
            return true
            
        } else {
            
            if getAppID() != nil {
                if ARPDebug {
                    NSLog("App Review Proctor: checkAppInfo() -> true")
                }
                return true
            } else {
                if ARPDebug {
                    NSLog("App Review Proctor: checkAppInfo() -> false")
                }
                return false
            }
            
        }
        
    }
    
}

// MARK: - Utility Methods
extension AppReviewProctor {
    
    // Wrapper function to clear all of the proctor conditions that must be satisfied
    // before an app will be reviewed.  We do this after an app review has been
    // requested to ensure that reviews only occur after an app has been used enough.
    //
    fileprivate static func clearProctorConditions() {
        if ARPDebug {
            NSLog("App Review Proctor: clearProctorConditions()")
        }
        let user_defaults = UserDefaults.standard as UserDefaults
        user_defaults.set(0, forKey: "\(DefaultBundleID)ARPEvents")
        user_defaults.set(0, forKey: "\(DefaultBundleID)ARPUses")
        user_defaults.removeObject(forKey: "\(DefaultBundleID)ARPRefusal")
        user_defaults.removeObject(forKey: "\(DefaultBundleID)ARPReminder")
        user_defaults.synchronize()
    }
    
    // Set the debug output level of ARP.  This will enable debug statements if you
    // have the compler flag -DDebug set in your compiler custom flags.
    fileprivate static func setDebugMode(_ enabled: Bool) {
        #if Debug
            ARPDebug = enabled
        #else
            print("App Review Proctor: Debug is disabled on release builds.")
            print("                    If you really want to enable debug mode,")
            print("                    add \"-DDebug\" to your  Swift Compiler - Custom Flags")
            print("                    section in the target's build settings for release.")
        #endif
    }
    
}

// MARK: - General Setup Methods
extension AppReviewProctor {
    
    // Set the app title associated with the app to be reviewed.
    // NOTE: This is becoming depreciated, we don't currently use it
    //
    // - (param) title: (String) your app name/title
    //
    public static func setAppTitle(_ title: String?) {
        
        guard let title = title else { return }
        
        if ARPDebug {
            NSLog("App Review Proctor: setAppTitle(\(title))")
        }
        
        let user_defaults = UserDefaults.standard as UserDefaults
        user_defaults.set(title, forKey: "\(DefaultBundleID)ARPTitle")
        user_defaults.synchronize()
        
    }
    
    // Set the text to be displayed on the app review request.
    //
    // - (param) text: (String) the text to be displayed
    //
    public static func setReviewText(_ text: String?) {
        
        guard let text = text else { return }
        
        if ARPDebug {
            NSLog("App Review Proctor: setReviewText(\(text))")
        }
        
        let user_defaults = UserDefaults.standard as UserDefaults
        user_defaults.set(text, forKey: "\(DefaultBundleID)ARPText")
        user_defaults.synchronize()
        
    }
    
    // Set the app store id for the review request.
    //
    // - (param) id: (String) your app's app store id
    //
    public static func setAppID(_ id: String?) {
        
        guard let id = id else { return }
        
        if ARPDebug {
            NSLog("App Review Proctor: setAppID(\(id))")
        }
        
        let user_defaults = UserDefaults.standard as UserDefaults
        user_defaults.set(id, forKey: "\(DefaultBundleID)ARPID")
        user_defaults.synchronize()
        
        // the first time the app id is set will mark the install
        // date, which is one of the proctoring conditions.  this
        // function only adds the date the first time the function
        // is called during the app lifecycle.
        addInstallDate()
        
    }
    
    // Set the affiliate code to be used for a direct app review.
    //
    // - (param) code: (String) your apple affiliate code
    //
    public static func setAffiliateCode(_ code: String?) {
        
        guard let code = code else { return }
        
        if ARPDebug {
            NSLog("App Review Proctor: setAffiliateCode(\(code))")
        }
        
        let user_defaults = UserDefaults.standard as UserDefaults
        user_defaults.set(code, forKey: "\(DefaultBundleID)ARPAffiliateCode")
        user_defaults.synchronize()
        
    }
    
    // Set the affiliate campaign code to be used for a direct app review.
    //
    // - (param) code: (String) your apple affiliate campaign code
    //
    public static func setAffiliateCampaignCode(_ code: String?) {
        
        guard let code = code else { return }
        
        if ARPDebug {
            NSLog("App Review Proctor: setAffiliateCampaignCode(\(code))")
        }
        
        let user_defaults = UserDefaults.standard as UserDefaults
        user_defaults.set(code, forKey: "\(DefaultBundleID)ARPAffiliateCampaignCode")
        user_defaults.synchronize()
        
    }
    
    // Get the app title associated with the app to be reviewed.
    // NOTE: This is becoming depreciated, we don't currently use it
    //
    fileprivate static func getAppTitle() -> String {
        
        let user_defaults = UserDefaults.standard as UserDefaults
        
        // look to see if the app title has been set as something other than the default
        if let app_title: String = user_defaults.value(forKey: "\(DefaultBundleID)ARPTitle") as? String {
            if ARPDebug {
                NSLog("App Review Proctor: getAppTitle() -> \(app_title)")
            }
            return app_title
        } else {
            if ARPDebug {
                NSLog("App Review Proctor: getAppTitle() -> \(DefaultAppTitle)")
            }
            return DefaultAppTitle
        }
        
    }
    
    // Get the app version associated with the app to be reviewed.
    // NOTE: This is becoming depreciated, we don't currently use it
    //
    fileprivate static func getAppVersion() -> String {
        if ARPDebug {
            NSLog("App Review Proctor: getAppVersion() -> \(DefaultAppVersion)")
        }
        return DefaultAppVersion!
    }
    
    // Get the text to be displayed on the app review request.
    //
    fileprivate static func getReviewText() -> String {
        
        let user_defaults = UserDefaults.standard as UserDefaults
        
        // look to see if the text has been set as something other than the default
        if let review_text: String = user_defaults.value(forKey: "\(DefaultBundleID)ARPText") as? String {
            if ARPDebug {
                NSLog("App Review Proctor: getReviewText() -> \(review_text)")
            }
            return review_text
        } else {
            if ARPDebug {
                NSLog("App Review Proctor: getReviewText() -> \(DefaultReviewText)")
            }
            return DefaultReviewText
        }
        
    }
    
    // Get the app store id for the review request.
    //
    fileprivate static func getAppID() -> String? {
        
        let user_defaults = UserDefaults.standard as UserDefaults
        
        // look to see if the app ID has been set and return nil if it has not
        if let app_id: String = user_defaults.value(forKey: "\(DefaultBundleID)ARPID") as? String {
            if ARPDebug {
                NSLog("App Review Proctor: getAppID() -> \(app_id)")
            }
            return app_id
        } else {
            if ARPDebug {
                NSLog("App Review Proctor: getAppID() -> nil")
            }
            return nil
        }
        
    }
    
    // Get the affiliate code to be used for a direct app review.
    //
    fileprivate static func getAffiliateCode() -> String {
        
        var affiliate_code: String = String()
        let user_defaults = UserDefaults.standard as UserDefaults
        
        if let affiliate_code_check: String = user_defaults.value(forKey: "\(DefaultBundleID)ARPAffiliateCode") as? String {
            affiliate_code = affiliate_code_check
        } else {
            affiliate_code = DefaultAffiliateCode
        }
        
        if ARPDebug {
            NSLog("App Review Proctor: getAffiliateCode() -> \(affiliate_code)")
        }
        
        return affiliate_code
        
    }
    
    // Get the affiliate campaign code to be used for a direct app review.
    //
    fileprivate static func getAffiliateCampaignCode() -> String {
        
        var affiliate_campaign_code: String = String()
        let user_defaults = UserDefaults.standard as UserDefaults
        
        if let affiliate_campaign_code_check: String = user_defaults.value(forKey: "\(DefaultBundleID)ARPAffiliateCampaignCode") as? String {
            affiliate_campaign_code = affiliate_campaign_code_check
        } else {
            affiliate_campaign_code = DefaultAffiliateCampaignCode
        }
        
        if ARPDebug {
            NSLog("App Review Proctor: getAffiliateCampaignCode() -> \(affiliate_campaign_code)")
        }
        
        return affiliate_campaign_code
        
    }
    
}

// MARK: - Display Method
extension AppReviewProctor {
    
    // We wrap this into a separate function so we can preserve backward
    // compatibility with older versions of iOS that don't support the
    // apple-provided review infrastructure.  We also conditionalize for
    // the base SDK in use to allow for development across multiple versions
    // of the iOS SDK (even though the entire purpose of this library is
    // to add more control to the display of SKStoreReviewController)
    //
    fileprivate static func displayPrompt() {
        
        // Only EXECUTE the SKStoreReviewController if the USER uses an
        // OS that supports it.  As a backup, we implement a simple
        // UIAlertController that facilitates app review.
        if #available(iOS 10.3, *) {
            
            // Only COMPILE SKStoreReviewController if the DEVELOPER has base
            // SDK support for it.  No clue why they would be using ARP without
            // it, as Armchair is way better for reviews prior to the 10.3 SDK,
            // and App Review Proctor is specifically for use with SKStoreReviewController.
            #if swift(>=3.1)
                
                // use SKStoreReviewController
                if ARPDebug {
                NSLog("App Review Proctor: Using SKStoreReviewController")
                }
                
                // add a new "last review" date
                addReviewDate()
                
                SKStoreReviewController.requestReview()
                
            #else
                
                // use UIAlertController
                if ARPDebug {
                    NSLog("App Review Proctor: Using UIAlertController")
                }
                
                let review_text = getReviewText().ARPlocalized
                
                let alert_controller = UIAlertController(title: "Rate This App".ARPlocalized, message: "\(review_text)", preferredStyle: UIAlertControllerStyle.actionSheet)
                
                alert_controller.addAction(UIAlertAction(title: "No, Thanks".ARPlocalized, style: UIAlertActionStyle.cancel) { (_) -> Void in
                    
                    if ARPDebug {
                        NSLog("App Review Proctor: Review Declined")
                    }
                    
                    // set a refusal date, which will be a first point of failure for a proctored request
                    // for any requests during the next 91 days
                    addRefusalDate()
                    
                })
                
                alert_controller.addAction(UIAlertAction(title: "Remind Me Later".ARPlocalized, style: UIAlertActionStyle.destructive) { (_) -> Void in
                    
                    if ARPDebug {
                        NSLog("App Review Proctor: Review Delayed")
                    }
                    
                    // add a reminder date, which will be the second point of failure.  a request will
                    // pass this check after the reminder threshold number of days has passed.
                    addReminderDate()
                    
                })
                
                alert_controller.addAction(UIAlertAction(title: "OK".ARPlocalized, style: UIAlertActionStyle.default) { (_) -> Void in
                    
                    if ARPDebug {
                        NSLog("App Review Proctor: Review Accepted")
                    }
                    
                    // clear out the use-based conditions (as opposed to "time-based")
                    clearProctorConditions()
                    
                    // add a new "last review" date
                    addReviewDate()
                    
                    let app_store_id = getAppID()
                    directReview(app_store_id)
                    
                })
                
                UIApplication.shared.keyWindow?.rootViewController?.present(alert_controller, animated: true, completion: nil)
                
            #endif
            
        } else {
            
            // NOTE: we could go back and support UIAlertView for iOS < 8.0, but at
            //       the time of ARP's initial release, nobody should be running an
            //       OS that old and we cannot support everything.
            
            // use UIAlertController
            if ARPDebug {
                NSLog("App Review Proctor: Using UIAlertController")
            }
            
            let review_text = getReviewText().ARPlocalized
            
            let alert_controller = UIAlertController(title: "Rate This App".ARPlocalized, message: "\(review_text)", preferredStyle: UIAlertControllerStyle.actionSheet)
            
            alert_controller.addAction(UIAlertAction(title: "No, Thanks".ARPlocalized, style: UIAlertActionStyle.default) { (_) -> Void in
                
                if ARPDebug {
                    NSLog("App Review Proctor: Review Declined")
                }
                
                // set a refusal date, which will be a first point of failure for a proctored request
                // for any requests during the next 91 days
                addRefusalDate()
                
            })
            
            alert_controller.addAction(UIAlertAction(title: "Remind Me Later".ARPlocalized, style: UIAlertActionStyle.default) { (_) -> Void in
                
                if ARPDebug {
                    NSLog("App Review Proctor: Review Delayed")
                }
                
                // add a reminder date, which will be the second point of failure.  a request will
                // pass this check after the reminder threshold number of days has passed.
                addReminderDate()
                
            })
            
            alert_controller.addAction(UIAlertAction(title: "OK".ARPlocalized, style: UIAlertActionStyle.default) { (_) -> Void in
                
                if ARPDebug {
                    NSLog("App Review Proctor: Review Accepted")
                }
                
                // clear out the use-based conditions (as opposed to "time-based")
                clearProctorConditions()
                
                // add a new "last review" date
                addReviewDate()
                
                let app_store_id = getAppID()
                directReview(app_store_id)
                
            })
            
            UIApplication.shared.keyWindow?.rootViewController?.present(alert_controller, animated: true, completion: nil)
            
        }
        
    }
    
}

extension String {
    var ARPlocalized: String {
        //let path = Bundle(for: AppReviewProctor.self).path(forResource: "AppReviewProctor", ofType: "bundle")!
        //let bundle = Bundle(path: path) ?? Bundle.main
        return NSLocalizedString(self, tableName: nil, bundle: Bundle.main, value: "", comment: "")
    }
}
