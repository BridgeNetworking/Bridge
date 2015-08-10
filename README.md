# Bridge [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
Simple HTTP Networking

```
var endpoint = GET<Dict>("https://api.github.com/users/whatever")
endpoint.execute(success: { (response) in
    print(response)
})
```


### TODO
- [ ] Documentation
- [ ] Error handling
- [x] Generics Branch

### Requirements
 - iOS 8.0+
 - Swift 2.0
 
### Installation

Carthage

`github "rawrjustin/Bridge"`
