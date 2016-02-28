//
//  TweetWordProcessor.swift
//  SoundsOfTwitter
//
//  Created by Eric Yanush on 2015-11-29.
//  Copyright © 2015 EricYanush. All rights reserved.
//

import Foundation
import TwitterKit
import MIKMIDI

/**
 Random, word based audio genenerator for tweets
*/
class WordRandomProcessor: TweetProcessor {
    
    private static var min_val: UInt8 = 21
    private static var max_val: UInt8 = 108
    
    static var minVal: UInt8 {
        get {
            return min_val
        }
        set {
            if (newValue < 21) {
                min_val = 21
            }
            else {
                min_val = newValue
            }
        }
    }
    
    static var maxVal: UInt8 {
        get {
            return max_val
        }
        set {
            if (newValue > 108) {
                max_val = 108
            }
            else {
                max_val = newValue
            }
        }
    }
    
    /**
     Process a single tweet
     - parameter jsonData: The tweet to process reprented as JSON data
     - parameter baseTimeStamp: The time to use as '0' time for the new generated audio
    */
    static func processTweet(tweet: TWTRTweet, baseTimeStamp: Float64) -> MidiTweet {
        var events = [MIKMIDIEvent]()

        let stringData = tweet.text
        //split the string into words
        let words = stringData.componentsSeparatedByString(" ")
        let totalCharCount = stringData.utf8.count
        let avgCharCount = Float32(totalCharCount / words.count)
        //iterate over the words in the message
        var currWord = 0.0
        for word: String in words {
            //Sum the characters, using overflow addition
            let sum = (word.utf8.reduce(0, combine: {$0 &+ $1}) % 127)
            let noteVal = max(min(maxVal, sum), minVal)
            let charCount = word.utf8.count
            //Skip empty words
            if (charCount == 0) {
                continue
            }
            
            let duration = min((Float32(charCount)/avgCharCount), Float32(words.count))
            let velocity = UInt8((charCount * 10) % 127)
            let message = MIKMIDINoteEvent(timeStamp: baseTimeStamp + currWord, note: noteVal, velocity: velocity, duration: duration, channel: 0)
            events.append(message!)
            
            currWord++
        }
        let t = MidiTweet(tweet: tweet, events: events)
        return t
    }
}