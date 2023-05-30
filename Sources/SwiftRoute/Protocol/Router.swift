//
//  Router.swift
//  SwiftMediator
//
//  Created by iOS on 2023/5/26.
//

import Foundation
import UIKit

/// 扩展路由类,添加一个以register开头的注册函数,返回一个RoutePath对象
/// Extend the routing class, add a registration function starting with register, and return a RoutePath object
public class Router: NSObject{
    public static let shared = Router()
    private override init(){
        super.init()
        registerMethods()
    }
    
    private var routers: [String: AnyClass] = [:]
    
    private func registerMethods(){
        var methodCount: UInt32 = 0
        if let methodList = class_copyMethodList(Router.self, &methodCount) {
            for i in 0..<Int(methodCount) {
                let method = methodList[i]
                let methodName = sel_getName(method_getName(method))
                let name = String(cString: methodName)
                if name.hasPrefix("register"){
                    let sel: Selector = NSSelectorFromString(name)
                    if responds(to: sel),
                       let result = perform(sel).takeUnretainedValue() as? RoutePath {
                        routers[result.path] = result.routerClass
                    }
                }
            }
            free(methodList)
        } else {
            print("No methods found for class \(Router.self).")
        }
    }
    
    private func getRoutableVC(_ urlString: String, params: [String: Any]?) -> Routable? {
        guard let url = URL(string: urlString), let urlScheme = url.scheme else { return nil }
        
        var routerModel: AnyClass? = routers[urlScheme]
        
        if let _ = routerModel {
            
        }else{
            let path = urlString.components(separatedBy: "?").first ?? ""
            routerModel = routers[path]
        }
        
        let par = params ?? [:]
        
        if let cls = routerModel, let routable = (cls as? Routable.Type)?.initVC(params: par) {
            return routable
        }
        return nil
    }
    
}

extension Router {
    
    /// Call the function of the instance object
    /// - Parameters:
    /// - instance: Routable
    /// - params: The parameter dictionary that needs to be passed to call the function
    /// - callback: closure callback
    public func callInstanceFunc(_ instance: Routable,
                                 params: [String: Any] = [:],
                                 callback: ((Any?) -> Void)? = nil){
        let completion = callback ?? { _ in }
        instance.callInstanceFunc(params: params, callback: completion)
    }
    
    /// Call the function of the instance object
    /// - Parameters:
    /// - path: the path of the registered instance (used to create the instance)
    /// - params: The parameter dictionary that needs to be passed to call the function
    /// - callback: closure callback
    public func callInstanceFunc(_ path: String,
                                 params: [String: Any] = [:],
                                 callback: ((Any?) -> Void)? = nil){
        guard let routable = getRoutableVC(path, params: params) else {
            return
        }
        let completion = callback ?? { _ in }
        routable.callInstanceFunc(params: params, callback: completion)
    }
    
    /// Call the function of the static object
    /// - Parameters:
    /// - path: the path of the registered instance (used to create the instance)
    /// - params: The parameter dictionary that needs to be passed to call the function
    /// - callback: closure callback
    public func callStaticFunc(_ path: String,
                               params: [String: Any] = [:],
                               callback: ((Any?) -> Void)? = nil){
        guard let url = URL(string: path), let urlScheme = url.scheme else { return }
        
        var routerModel: AnyClass? = routers[urlScheme]
        
        if let _ = routerModel {
            
        }else{
            let path = path.components(separatedBy: "?").first ?? ""
            routerModel = routers[path]
        }
        
        let completion = callback ?? { _ in }
        
        if let cls = routerModel, let routable = cls as? Routable.Type {
            routable.callStaticFunc(params: params, callback: completion)
        }
    }
}

extension Router {
    /// Routing Push
    /// - Parameters:
    /// - fromVC: Jump from that page--if not passed, the top VC is taken by default
    /// - path: Register the path.
    /// - params: parameter dictionary
    /// - animated: whether there is animation
    public func push(_ path: String,
                     params: [String: Any]? = [:],
                     fromVC: UIViewController? = nil,
                     animated: Bool = true) {
        guard let routable = getRoutableVC(path, params: params) as? UIViewController else {
            return
        }
        routable.hidesBottomBarWhenPushed = true
        guard let from = fromVC else {
            UIViewController.currentNavigationController()?.pushViewController(routable, animated: animated)
            return
        }
        from.navigationController?.pushViewController(routable, animated: animated)
    }
    
    /// The current UINavigationController pop to the previous page
    /// - Parameter animated: animated
    public func pop(animated: Bool = true){
        guard let nav = UIViewController.currentNavigationController() else { return }
        nav.popViewController(animated: animated)
    }
    
    /// The current UINavigationController pop to the Root page
    /// - Parameter animated: animated
    public func popToRoot(animated: Bool = true){
        guard let nav = UIViewController.currentNavigationController() else { return }
        nav.popToRootViewController(animated: animated)
    }
    
    /// route present
    /// - Parameters:
    /// - fromVC: Jump from that page--if not passed, the top VC is taken by default
    /// - path: Register the path.
    /// - params: parameter dictionary
    /// - modelStyle: 0: modal style is default, 1: full screen modal, 2: custom
    /// - needNav: Do you need a navigation bar (native navigation bar, if you need a custom navigation bar, please directly pass the corresponding VC object with navigation bar)
    /// - animated: whether there is animation
    public func present(_ path: String,
                        params: [String: Any]? = [:],
                        fromVC: UIViewController? = nil,
                        needNav: Bool = false,
                        modelStyle: UIModalPresentationStyle = .fullScreen,
                        animated: Bool = true) {
        
        guard let routable = getRoutableVC(path, params: params) as? UIViewController else {
            return
        }
        var container = routable
        
        if needNav {
            let nav = UINavigationController(rootViewController: container)
            container = nav
        }
        
        container.modalPresentationStyle = modelStyle
        
        guard let from = fromVC else {
            UIViewController.currentViewController()?.present(container, animated: animated, completion: nil)
            return
        }
        from.present(container, animated: animated, completion: nil)
    }
    
    /// Exit the current page
    public func dismissVC(animated: Bool = true) {
        let current = UIViewController.currentViewController()
        if let viewControllers: [UIViewController] = current?.navigationController?.viewControllers {
            guard viewControllers.count <= 1 else {
                current?.navigationController?.popViewController(animated: animated)
                return
            }
        }
        
        if let _ = current?.presentingViewController {
            current?.dismiss(animated: animated, completion: nil)
        }
    }
    /// URL routing jump Jump to distinguish Push, present, fullScreen
    /// - Parameter urlString: Call native page function push://XXXX?quereyParams
    public func open(_ urlString: String) {
        
        guard let url = URL(string: urlString) else { return }
        guard let routable = getRoutableVC(urlString, params: url.urlParameters) else {
            return
        }
        routable.openRouter(path: urlString)
    }
}
