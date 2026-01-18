//
//  NoteWidgetBundle.swift
//  NoteWidget
//
//  Created by Gyeongho Yang on 18.01.26.
//

import WidgetKit
import SwiftUI

@main
struct NoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        NoteWidget()
        NoteWidgetControl()
    }
}
