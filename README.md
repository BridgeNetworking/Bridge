# Bridge [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
Simple HTTP Networking

```
var endpoint = GET("https://api.github.com/zen")
endpoint.execute(success: { (response) in
    print(response)
})
```


### TODO
- [ ] Documentation
- [ ] Error handling
- [ ] Generic Branch
- [ ] Chaining response > requests

### Requirements
 - iOS 8.0+
 - Swift 2.0
 
### Installation

Carthage

`github "rawrjustin/Bridge"`
