#CachedRequester

Simple, light-weight network requester with auto-purging in-memory cache.

##Installation

###CocoaPods

In your project root:

```
$ pod init
```

Then open `Podfile` and add `CachedRequester` to our pods list:

```
$ pod 'CachedRequester'
```

After that install the pods and open the workspace:

```
$ pod install
$ open PROJECT_NAME.xcworkspace
```

###Carthage

Install [Carthage](https://github.com/Carthage/Carthage) if you haven't already.

Create a `Cartfile` in your project root with the cart info

```
$ echo 'github "mnvoh/CachedRequester"' > Cartfile
```

Install the packages

```
$ carthage update
```

Open Xcode, then navigate to `{PROJECT_ROOT}/Carthage/Build/iOS` and drag `CachedRequester.framework` into your project in Xcode.

And finally navigate to `Project Properties->General->Embedded Binaries` and add `CachedRequester.framework` to the list.


## Usage

If you're not comfortable with the default configurations, first configure the shared instance of the library in your `AppDelegate.swift`

```
CachedRequester.sharedInstance.autostart = true // default value
CachedRequester.sharedInstance.inMemoryCacheSizeLimit = 200 * 1024 * 1024 // 200 MiB, the default value
CachedRequester.sharedInstance.inMemoryCacheSizeLimitAfterPurge = 150 * 1024 * 1024 // 150 MiB, the default value

```


Everywhere else:

```
import CachedRequester
...

let url = URL(string: "url_to_resource")!
let task = Requester.sharedInstance.newTask(url: url, completionHandler: { (data, error) in
  guard error = nil, let data = data else {
    // do something with the error
    return
  }
  
  // do something with the data
  let image = UIImage(data: data)
  // or
  let json = JSONSerialization.jsonObject(with: data, options: .allowFragments)
  // or ...
}) { (progress) in
  self.progressbar.progress = Float(progress)
}
```