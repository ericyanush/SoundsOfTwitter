//
//  WordScaleProcessor.swift
//  SoundsOfTwitter
//
//  Created by Eric Yanush on 2015-11-30.
//  Copyright © 2015 EricYanush. All rights reserved.
//

import Foundation
import TwitterKit
import MIKMIDI
import MusicKit

class WordScaleProcessor : TweetProcessor {
    
    private static var min_oct: UInt8 = 2
    private static var max_oct: UInt8 = 7
    
    static var minOctave: UInt8 {
        get {
        return min_oct
        }
        set {
            min_oct = newValue
            setScale(curr_chroma, scaleType: curr_scale)
        }
    }
    
    static var maxOctave: UInt8 {
        get {
        return max_oct
        }
        set {
            max_oct = newValue
            setScale(curr_chroma, scaleType: curr_scale)
        }
    }
    
    private static var curr_chroma: Chroma = Chroma.C
    private static var curr_scale: Harmonizer = Scale.Major
    private static var scale_set: PitchSet = PitchSet()
    static var scale: PitchSet {
        get {
            return scale_set
        }
    }
    static func setScale(chroma: Chroma, scaleType: Harmonizer) {
        scale_set = PitchSet()
        for i in min_oct ... max_oct {
            scale_set += scaleType(chroma*Int(i))
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
            let sum = (word.utf8.reduce(0, combine: {$0 &+ $1}) % 127)
            let noteVal: Pitch = roundPitch( Pitch(midi: Float(sum)) )
            assert(scale_set.contains(noteVal))
            let charCount = word.utf8.count
            //Skip empty words
            if (charCount == 0) {
                continue
            }
            
            let duration = min((Float32(charCount)/avgCharCount), Float32(words.count))
            let velocity = UInt8((charCount * 10) % 127)
            let message = MIKMIDINoteEvent(timeStamp: baseTimeStamp + currWord, note: UInt8(noteVal.midi), velocity: velocity, duration: duration, channel: 0)
            events.append(message!)
            
            currWord++
        }
        
        return MidiTweet(tweet: tweet, events: events)
    }
    
    private class func roundPitch(pitch: Pitch) -> Pitch {
        var roundedPitch = pitch
        
        var leftIdx = 0
        var rightIdx = scale_set.count - 1
        //check if pitch less than lowest in set
        if scale_set.count > 0 {
            if pitch < scale_set.first()! {
                return scale_set.first()!
            }
            else if pitch > scale_set.last()! {
                return scale_set.last()!
            }
        }
        while leftIdx <= rightIdx {
            let middleIdx = (leftIdx + rightIdx) / 2
            let val = scale_set[middleIdx]
            
            if val == pitch  {
                return roundedPitch
            }
            else if val < pitch {
                //check if the next element in the set is > pitch
                if (middleIdx + 1) < scale_set.count && scale_set[middleIdx+1] > pitch {
                    //we are in between these two pitches, need to round to nearest
                    let nextVal = scale_set[middleIdx+1]
                    let leftDist = abs(pitch.midi - val.midi)
                    let rightDist = abs(nextVal.midi - pitch.midi)
                    if leftDist < rightDist {
                        roundedPitch = val
                    }
                    else {
                        roundedPitch = nextVal
                    }
                    return roundedPitch
                }
                else {
                    leftIdx = middleIdx + 1
                }
            }
            else if (val > pitch) {
                //check if prev element in set is < pitch
                if (middleIdx - 1) > 0  && scale_set[middleIdx-1] < pitch {
                    //we are between two pitches and need to round
                    let prevVal = scale_set[middleIdx-1]
                    let leftDist = abs(pitch.midi - prevVal.midi)
                    let rightDist = abs(val.midi - pitch.midi)
                    if leftDist < rightDist {
                        roundedPitch = prevVal
                    }
                    else {
                        roundedPitch = val
                    }
                    return roundedPitch
                }
                else {
                    rightIdx = middleIdx - 1
                }
            }
        }
        return roundedPitch
    }
}