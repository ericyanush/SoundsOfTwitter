//
//  WordSingleToneProcessor.swift
//  SoundsOfTwitter
//
//  Created by Eric Yanush on 2015-11-30.
//  Copyright © 2015 EricYanush. All rights reserved.
//

import Foundation
import TwitterKit
import MIKMIDI

/**
 Random, word based audio genenerator for tweets
 */
class WordSingleToneProcessor: TweetProcessor {
    /**
     Process a single tweet
     - parameter jsonData: The tweet to process reprented as JSON data
     - parameter baseTimeStamp: The time to use as '0' time for the new generated audio
     */
    
    private static var tone_val: UInt8 = 21
    static var tone : UInt8 {
        get {
            return tone_val
        }
        set {
            if (newValue > 108) {
                tone_val = 108
            }
            else if (newValue < 21) {
                tone_val = 21
            }
            else {
                tone_val = newValue
            }
        }
    }
    
    class func processTweet(tweet: TWTRTweet, baseTimeStamp: Float64) -> MidiTweet {
        var events = [MIKMIDIEvent]()
        
        //split the string into words
        let words = tweet.text.componentsSeparatedByString(" ")
        let totalCharCount = tweet.text.utf8.count
        let avgCharCount = Float32(totalCharCount / words.count)
        //iterate over the words in the message
        var currWord = 0.0
        for word: String in words {
            //Sum the characters, using overflow addition
            let charCount = word.utf8.count
            //Skip empty words
            if (charCount == 0) {
                continue
            }
            
            let duration = min((Float32(charCount)/avgCharCount), Float32(words.count))
            let velocity = UInt8((charCount * 10) % 127)
            let message = MIKMIDINoteEvent(timeStamp: baseTimeStamp + currWord, note: tone_val, velocity: velocity, duration: duration, channel: 0)
            events.append(message!)
            
            currWord++
        }
        return MidiTweet(tweet: tweet, events: events)
    }
}