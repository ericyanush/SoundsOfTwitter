//
//  TweetProcessor.swift
//  SoundsOfTwitter
//
//  Created by Eric Yanush on 2015-11-29.
//  Copyright © 2015 EricYanush. All rights reserved.
//
import SwiftyJSON
import MIKMIDI
import TwitterKit

protocol TweetProcessor {
    static func processTweet(tweet: TWTRTweet, baseTimeStamp: Float64) -> MidiTweet
}

extension TweetProcessor {
    static func processTweets(tweets: [TWTRTweet], baseTimeStamp: Float64) -> [MidiTweet] {
        var midiTweets = [MidiTweet]()
        for tweet in tweets {
            var ts: Float64
            if midiTweets.count == 0 {
                ts = baseTimeStamp
            }
            else {
                ts = midiTweets.last!.endTimeStamp
            }
            midiTweets.append(processTweet(tweet, baseTimeStamp: ts))
        }
        return midiTweets
    }
    
}