//
//  LocalizationManager.swift
//  sing-box
//
//  Created by Petr Romanov on 30.10.2024.
//

import Foundation


class LanguageManager: ObservableObject {
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "appLanguage")
            Bundle.setLanguage(currentLanguage)
        }
    }
    
    init() {
        self.currentLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "ru"
        Bundle.setLanguage(currentLanguage)
    }
}

extension Bundle {
    private static var bundle: Bundle!

    static func setLanguage(_ language: String) {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return
        }
        self.bundle = bundle
    }

    static func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        return bundle?.localizedString(forKey: key, value: value, table: tableName) ?? key
    }
}

//class LanguageManager: ObservableObject {
//    @Published var locale: Locale
//    
////    init() {
////        // Загружаем сохраненный язык из UserDefaults или устанавливаем "en" по умолчанию
////        let languageCode = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
////        locale = Locale(identifier: languageCode)
////    }
//    
//    init() {
//        
//        
//        
//            // Проверяем, установлен ли язык в UserDefaults
//            if let savedLanguageCode = UserDefaults.standard.string(forKey: "appLanguage") {
//                // Если сохраненный язык найден, используем его
//                print("lang________________\(savedLanguageCode)")
//                locale = Locale(identifier: savedLanguageCode)
//                changeLanguage(to: savedLanguageCode)
//            } else {
//                // Если нет, устанавливаем язык по умолчанию (например, системный или "en")
//                let defaultLanguageCode = Locale.current.language.languageCode?.identifier ?? "ru"
//                locale = Locale(identifier: defaultLanguageCode)
//                
//                // Сохраняем язык по умолчанию в UserDefaults
////                UserDefaults.standard.set(defaultLanguageCode, forKey: "appLanguage")
//                changeLanguage(to: defaultLanguageCode)
//            }
//        }
//    
//    func changeLanguage(to languageCode: String) {
//        // Сохраняем новый язык и обновляем локаль
//        UserDefaults.standard.set(languageCode, forKey: "appLanguage")
//        locale = Locale(identifier: languageCode)
//    }
//}
