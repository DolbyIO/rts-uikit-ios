<!--
[![Build Package](https://github.com/dolbyio-samples/template-repo/actions/workflows/build-package.yml/badge.svg)](https://github.com/dolbyio-samples/template-repo/actions/workflows/build-package.yml)
[![Publish Package](https://github.com/dolbyio-samples/template-repo/actions/workflows/publish-package.yml/badge.svg)](https://github.com/dolbyio-samples/template-repo/actions/workflows/publish-package.yml)
[![npm](https://img.shields.io/npm/v/dolbyio-samples/template-repo)](https://www.npmjs.com/package/dolbyio-samples/template-repo)
[![License](https://img.shields.io/github/license/dolbyio-samples/template-repo)](LICENSE)

Adding shields would also be amazing -->

# Dolby.io Real-time Streaming UIKit for iOS

# Overview
The Dolby.io Real-time Streaming UIKit for iOS is design to help iOS developers reduce the complexity of building a Dolby.io Real-time Streaming monitoring applications for iOS.

The package consists of three components:  
* `DolbyIORTSUIKit`: The high-level UI components can be used to develop a real-time streaming monitoring app for iOS with Dolby.io.  
* `DolbyIORTSCore`: The logic between `DolbyIORTSUIKit` and Dolby.io Real-time Streaming iOS SDK.   
* `DolbyUIUIKIt`: The basic UI components used by `DolbyIORTSUIKit`.  

> **_Info:_** There are two parties in a real-time streaming. A publisher who broadcasts a streaming. A monitor(viewer) who consumes a streaming. This UIKit is targeting to a monitor who consumes a streaming.

# Requirements

This setup guide is validated on both Intel/M1-based MacBook Pro running macOS 13.4.

- Xcode Version 14.3.1 (14E300c)
- iPhone device or simulator running iOS 15.0

# Getting Started

This guide demostrates how to use the Real-time Streaming UI components to quickly build a Real-time Steaming monitoring app on an iOS device.

## Build a Sample App

Get started by a working sample app, see below.

* Create a new Xcode project
* Choose the iOS App as template
* Fill in the Product Name
* Select "SwiftUI" as Interface
* Select "Swift" as Language
* Create the project in a folder
* Add this UIKit as dependencies to the newly created project.  
	* Go to File > Add Packages...
	* Put the URL of this repo in the pop-up window's top-right corner text field
	* Use `Up to Next Major Version` in the Dependency Rule
	* Click the `Add Package` button
	* Choose and add these packages `DolbyIORTSCore`,  `DolbyIORTSUIKit`, and `DolbyIOUIKIt` to the target
	* Click the `Add Package` button
* Copy and replace the code to ContentView.swift
* Compile and Run on an iOS target


```swift 
import SwiftUI

// 1. Include Dolby.io UIKit and related packages
import DolbyIORTSCore
import DolbyIORTSUIKit

struct ContentView: View {
    // 2. State to show the real-time streaming or not
    @State private var showStream = false

    var body: some View {
        NavigationView {
            ZStack {
            
            	// 3. Navigation link to the streaming screen if `showStream` is true
                NavigationLink(destination: StreamingScreen(isShowingStreamView: $showStream), isActive: $showStream) { EmptyView() }
                Button ("Start Stream") {
                
                	// 4. Asynchronize task connects the publisher with the given stream name and account ID. The stream name and 
                	// account ID pair here is from a demo stream. It can be replaced by a pair being given by a publisher who has 
                	// signed-up up the Dolby.io service. 
                    Task {
                        let success = await StreamCoordinator.shared.connect(streamName: "multiview", accountID: "k9Mwad")
                        
                        // 5. Show the real-time streaming if connect successfully
                        await MainActor.run { showStream = success }
                    }
                }
            }.preferredColorScheme(.dark)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
```


## Get a Dolby.io account

To publish a real-time stream, a Dolby.io account is necessary

- A [Dolby.io](https://dashboard.dolby.io/signup/) account
- Start a video streaming broadcasting, see [here](https://docs.dolby.io/streaming-apis/docs/how-to-broadcast-in-dashboard) 
- The Stream name and Account ID pair from the video streaming above

To setup your Dolby.io account, go to the [Dolby.io dashboard](https://dashboard.dolby.io/signup/) and complete the form. After confirming your email address, you will be logged in.  

## Installation

This UIKit package uses Swift Packages. You can add this package site URL as dependencies to your app. Detail can be find [here](https://developer.apple.com/documentation/xcode/swift-packages)

> **_Info:_** The main branch is constantly under development. Get a tagged branch for a stable release.

## License

The Dolby.io Real-time UIKit for iOS and its repository are licensed under the MIT License. Before using this, please review and accept the [Dolby Software License Agreement](LICENSE).

# About Dolby.io

Using decades of Dolby's research in sight and sound technology, Dolby.io provides APIs to integrate real-time streaming, voice & video communications, and file-based media processing into your applications. [Sign up for a free account](https://dashboard.dolby.io/signup/) to get started building the next generation of immersive, interactive, and social apps.

&copy; Dolby, 2023

<div align="center">
  <a href="https://dolby.io/" target="_blank"><img src="https://img.shields.io/badge/Dolby.io-0A0A0A?style=for-the-badge&logo=dolby&logoColor=white"/></a>
&nbsp; &nbsp; &nbsp;
  <a href="https://docs.dolby.io/" target="_blank"><img src="https://img.shields.io/badge/Dolby.io-Docs-0A0A0A?style=for-the-badge&logoColor=white"/></a>
&nbsp; &nbsp; &nbsp;
  <a href="https://dolby.io/blog/category/developer/" target="_blank"><img src="https://img.shields.io/badge/Dolby.io-Blog-0A0A0A?style=for-the-badge&logoColor=white"/></a>
</div>

<div align="center">
&nbsp; &nbsp; &nbsp;
  <a href="https://youtube.com/@dolbyio" target="_blank"><img src="https://img.shields.io/badge/YouTube-red?style=flat-square&logo=youtube&logoColor=white" alt="Dolby.io on YouTube"/></a>
&nbsp; &nbsp; &nbsp; 
  <a href="https://twitter.com/dolbyio" target="_blank"><img src="https://img.shields.io/badge/Twitter-blue?style=flat-square&logo=twitter&logoColor=white" alt="Dolby.io on Twitter"/></a>
&nbsp; &nbsp; &nbsp;
  <a href="https://www.linkedin.com/company/dolbyio/" target="_blank"><img src="https://img.shields.io/badge/LinkedIn-0077B5?style=flat-square&logo=linkedin&logoColor=white" alt="Dolby.io on LinkedIn"/></a>
</div>


