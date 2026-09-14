//
//  UNNotificationAttachment+Init.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 06/08/2020.
//  Copyright © 2020 Goodylabs. All rights reserved.
//

import Foundation
import UserNotifications

extension UNNotificationAttachment {
    convenience init?(url: String) throws {
        guard let imageUrl = URL(string: url) else {
            return nil
        }

        let pathExtension = imageUrl.pathExtension
        guard !pathExtension.isEmpty else {
            return nil
        }

        guard let imageData = try? Data(contentsOf: imageUrl),
              !imageData.isEmpty else {
            return nil
        }

        let fileManager = FileManager.default
        let fileUrl = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)

        do {
            try imageData.write(to: fileUrl)
            try self.init(
                identifier: fileUrl.lastPathComponent,
                url: fileUrl,
                options: nil
            )
        } catch {
            try? fileManager.removeItem(at: fileUrl)
            throw error
        }
    }
}
