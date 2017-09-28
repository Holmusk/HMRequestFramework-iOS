//
//  Singleton.swift
//  HMRequestFrameworkTests
//
//  Created by Hai Pham on 24/8/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

@testable import HMRequestFramework

public final class Singleton {
    public static func coreDataManager(_ mainContextMode: HMCDMainContextMode,
                                       _ store: HMCDStoreSettings.StoreType) -> HMCDManager {
        let fileManager = FileManager.default
        
        let url = HMCDStoreURL.builder()
            .with(fileManager: fileManager)
            .withDocumentDirectory()
            .withUserDomainMask()
            .with(fileName: "HMRequestFramework")
            .with(storeType: store)
            .build()
        
        print("Creating store at \(String(describing: try? url.storeURL()))")
        
        try? fileManager.removeItem(at: url.storeURL())
        
        let settings = [
            HMCDStoreSettings.builder()
                .with(storeType: store)
                .with(persistentStoreURL: url)
                .build()
        ]
        
        let constructor = HMCDConstructor.builder()
            .with(cdTypes: Dummy1.CDClass.self, Dummy2.CDClass.self)
            .with(settings: settings)
            .with(mainContextMode: mainContextMode)
            .build()
        
        return try! HMCDManager(constructor: constructor)
    }
    
    public static func dbProcessor(_ manager: HMCDManager) -> HMCDRequestProcessor {
        let rqmManager = HMFilterMiddlewareManager<HMCDRequest>.builder().build()
        
        return HMCDRequestProcessor.builder()
            .with(manager: manager)
            .with(rqmManager: rqmManager)
            .build()
    }
    
    private init() {}
}
