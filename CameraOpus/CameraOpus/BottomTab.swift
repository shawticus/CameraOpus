//
//  BottomTab.swift
//  CameraOpus
//
//  Created by Abheek Basu on 6/14/19.
//  Copyright © 2019 CameraOpus. All rights reserved.
//

import Foundation
import UIKit

class BottomTab: UITabBar, UITabBarControllerDelegate  {
    
    
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        
        print("in tabBar")
        
        if(item.tag == 0) {
            print("we are pressing tab 0")
            //your code for tab item 1
        }
        else if(item.tag == 1) {
            print("we are pressing tab 1")
            //your code for tab item 2
        }
        else if(item.tag == 2)
        {
            print("we are pressing tab 2")
            let storyboard = UIStoryboard(name: "ThreeDFileViewController", bundle: nil)
            let nextVc = storyboard.instantiateViewController(withIdentifier: "ThreeDFileViewController") as! ThreeDFileViewController
            let navigationVc = UINavigationController(rootViewController: nextVc)
            
            //navigationVc.pushViewController(nextVc, animated: false)
            
            //present(navigationVc, animated: false, completion: nil)
        }
        
    }

    
}