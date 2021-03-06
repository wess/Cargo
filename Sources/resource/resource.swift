import Foundation
import validation

open class Resource : Equatable {
  public static var tableName:String {
    return String(describing: self).lowercased().pluralize()
  }

  final private let lock                                    = DispatchSemaphore(value:1)
  public private(set) var errors:[String:[ValidationError]] = [:]

  final public lazy var properties:[String:ResourceProperty] = {
    self.lock.wait(); defer { self.lock.signal() }

    return Mirror(reflecting: self).children.filter({ $0.1 is ResourceProperty }).reduce([:]) { current, next in
      guard let key = next.0, let value = next.1 as? ResourceProperty else { return current }

      
      var dict  = current
      dict[key] = value
      
      return dict
    }
  }()

  final public var isValid:Bool {
    var errorCount = 0
    
    errors.removeAll()
    
    for (name, value) in properties {
      guard let property = value as? Property else { continue }
      
      if property.isValid == false {
        errors[name] = property.errors

        errorCount += 1
      }
    }

    return errorCount == 0
  }

  public init() {}

  public subscript(key:String) -> Any? {
    get {
      if let relationship = properties[key] as? Relationship {
        return relationship.list
      }
      
      if let property = properties[key] as? Property {
        return property.value
      }
      
      return nil
    }

    set {
      if let relationship = properties[key] as? Relationship {
        guard let resource = newValue as? Resource else { return }
        
        relationship.add(resource)
      }
      
      if let property = properties[key] as? Property {
        guard let value = newValue as? Validatable else { return }
        
        property.value = value
      }
    }
  }
}


public func ==(lhs:Resource, rhs:Resource) -> Bool {
  return String(describing: lhs).lowercased() == String(describing: rhs).lowercased()
}

public protocol ResourceProperty {}
