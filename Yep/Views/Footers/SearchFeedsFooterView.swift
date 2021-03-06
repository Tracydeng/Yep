//
//  SearchFeedsFooterView.swift
//  Yep
//
//  Created by NIX on 16/4/21.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import UIKit

class SearchFeedsFooterView: UIView {

    lazy var promptLabel: UILabel = {

        let label = UILabel()
        label.font = UIFont.systemFontOfSize(17)
        label.textColor = UIColor.darkGrayColor()
        label.textAlignment = .Center
        label.text = NSLocalizedString("Try any keywords", comment: "")
        return label
    }()

    lazy var keywordLabelA: UILabel = {

        let label = UILabel()
        label.font = UIFont.systemFontOfSize(13)
        label.textColor = UIColor.yepTintColor()
        label.textAlignment = .Center
        label.text = NSLocalizedString("iOS, Music ...", comment: "")
        return label
    }()

    lazy var keywordLabelB: UILabel = {

        let label = UILabel()
        label.font = UIFont.systemFontOfSize(13)
        label.textColor = UIColor.yepTintColor()
        label.textAlignment = .Center
        label.text = NSLocalizedString("Book, Food ...", comment: "")
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        makeUI()
   }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func makeUI() {
        addSubview(promptLabel)
        addSubview(keywordLabelA)
        addSubview(keywordLabelB)

        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        keywordLabelA.translatesAutoresizingMaskIntoConstraints = false
        keywordLabelB.translatesAutoresizingMaskIntoConstraints = false

        let views = [
            "promptLabel": promptLabel,
            "keywordLabelA": keywordLabelA,
            "keywordLabelB": keywordLabelB,
        ]

        let constraintsH = NSLayoutConstraint.constraintsWithVisualFormat("H:|[promptLabel]|", options: [], metrics: nil, views: views)

        let constraintsV = NSLayoutConstraint.constraintsWithVisualFormat("V:|-40-[promptLabel]-20-[keywordLabelA]-10-[keywordLabelB]-(>=0)-|", options: [.AlignAllCenterX], metrics: nil, views: views)

        NSLayoutConstraint.activateConstraints(constraintsH)
        NSLayoutConstraint.activateConstraints(constraintsV)
    }
}

