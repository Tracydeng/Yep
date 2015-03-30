//
//  MessageToolbar.swift
//  Yep
//
//  Created by NIX on 15/3/24.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit

enum MessageToolbarState {
    case Default
    case TextInput
}

@IBDesignable
class MessageToolbar: UIToolbar {

    var messageTextViewHeightConstraint: NSLayoutConstraint!

    let messageTextAttributes = [NSFontAttributeName: UIFont.systemFontOfSize(15)]

    var state: MessageToolbarState = .Default {
        willSet {
            switch newValue {
            case .Default:
                micButton.hidden = false
                sendButton.hidden = true

            case .TextInput:
                micButton.hidden = true
                sendButton.hidden = false
            }

            updateHeightOfMessageTextView()
        }
    }

    var textSendAction: ((messageToolBar: MessageToolbar) -> ())?
    
    var voiceSendAction: ((messageToolBar: MessageToolbar) -> ())?
    
    var voiceSendUpAction: ((messageToolBar: MessageToolbar) -> ())?
    
    var voiceSendCancelAction: ((messageToolBar: MessageToolbar) -> ())?

    lazy var cameraButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "item_camera"), forState: .Normal)
        button.tintColor = UIColor.yepTintColor()
        return button
        }()

    lazy var messageTextView: UITextView = {
        let textView = UITextView()
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.font = UIFont.systemFontOfSize(15)
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.yepTintColor().CGColor
        textView.layer.cornerRadius = 6
        textView.delegate = self
        textView.scrollEnabled = false // 重要：若没有它，换行时可能有 top inset 不正确
        return textView
        }()

    lazy var micButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "item_mic"), forState: .Normal)
        button.tintColor = UIColor.yepTintColor()
        button.addTarget(self, action: "trySendVoiceMessageBegin", forControlEvents: UIControlEvents.TouchDown)
        button.addTarget(self, action: "trySendVoiceMessageEnd", forControlEvents: UIControlEvents.TouchUpInside)
        button.addTarget(self, action: "trySendVoiceMessageCancel", forControlEvents: UIControlEvents.TouchUpOutside)
        return button
        }()

    lazy var sendButton: UIButton = {
        let button = UIButton()
        button.setTitle(NSLocalizedString("Send", comment: ""), forState: .Normal)
        button.setTitleColor(UIColor.yepTintColor(), forState: .Normal)
        button.addTarget(self, action: "trySendTextMessage", forControlEvents: UIControlEvents.TouchUpInside)
        return button
        }()

    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        makeUI()

        state = .Default
    }

    func makeUI() {

        self.addSubview(cameraButton)
        cameraButton.setTranslatesAutoresizingMaskIntoConstraints(false)

        self.addSubview(messageTextView)
        messageTextView.setTranslatesAutoresizingMaskIntoConstraints(false)

        self.addSubview(micButton)
        micButton.setTranslatesAutoresizingMaskIntoConstraints(false)

        self.addSubview(sendButton)
        sendButton.setTranslatesAutoresizingMaskIntoConstraints(false)

        let viewsDictionary = [
            "cameraButton": cameraButton,
            "messageTextView": messageTextView,
            "micButton": micButton,
            "sendButton": sendButton,
        ]

        let constraintsV = NSLayoutConstraint.constraintsWithVisualFormat("V:|[cameraButton(==micButton)]|", options: NSLayoutFormatOptions(0), metrics: nil, views: viewsDictionary)

        let messageTextViewConstraintsV = NSLayoutConstraint.constraintsWithVisualFormat("V:|-8-[messageTextView]-8-|", options: NSLayoutFormatOptions(0), metrics: nil, views: viewsDictionary)

        let textContainerInset = messageTextView.textContainerInset
        let constant = ceil(messageTextView.font.lineHeight + textContainerInset.top + textContainerInset.bottom)
        messageTextViewHeightConstraint = NSLayoutConstraint(item: messageTextView, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: constant)

        let constraintsH = NSLayoutConstraint.constraintsWithVisualFormat("H:|[cameraButton(48)][messageTextView][micButton(==cameraButton)]|", options: NSLayoutFormatOptions.AlignAllCenterY, metrics: nil, views: viewsDictionary)

        NSLayoutConstraint.activateConstraints(constraintsV)
        NSLayoutConstraint.activateConstraints(constraintsH)
        NSLayoutConstraint.activateConstraints(messageTextViewConstraintsV)
        NSLayoutConstraint.activateConstraints([messageTextViewHeightConstraint])


        let sendButtonConstraintCenterY = NSLayoutConstraint(item: sendButton, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: cameraButton, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: 0)

        let sendButtonConstraintHeight = NSLayoutConstraint(item: sendButton, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: cameraButton, attribute: NSLayoutAttribute.Height, multiplier: 1, constant: 0)

        let sendButtonConstraintsH = NSLayoutConstraint.constraintsWithVisualFormat("H:[messageTextView][sendButton(==cameraButton)]|", options: NSLayoutFormatOptions.AlignAllCenterY, metrics: nil, views: viewsDictionary)

        NSLayoutConstraint.activateConstraints([sendButtonConstraintCenterY])
        NSLayoutConstraint.activateConstraints([sendButtonConstraintHeight])
        NSLayoutConstraint.activateConstraints(sendButtonConstraintsH)
    }


    // Mark: Helpers

    func updateHeightOfMessageTextView() {

        let size = messageTextView.sizeThatFits(CGSize(width: CGRectGetWidth(messageTextView.bounds), height: CGFloat(FLT_MAX)))

        let newHeight = size.height

        //println("oldHeight: \(messageTextViewHeightConstraint.constant), newHeight: \(newHeight)")

        if newHeight != messageTextViewHeightConstraint.constant {
            UIView.animateWithDuration(0.1, delay: 0.0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
                self.messageTextViewHeightConstraint.constant = newHeight
                self.layoutIfNeeded()
            }, completion: { (finished) -> Void in
            })
        }
    }

    func trySendTextMessage() {
        if let textSendAction = textSendAction {
            textSendAction(messageToolBar: self)
        }
    }
    
    func trySendVoiceMessageBegin() {
        if let textSendAction = voiceSendAction {
            textSendAction(messageToolBar: self)
        }
    }
    
    func trySendVoiceMessageEnd() {
        if let textSendAction = voiceSendUpAction {
            textSendAction(messageToolBar: self)
        }
    }
    
    func trySendVoiceMessageCancel() {
        if let textSendAction = voiceSendCancelAction {
            textSendAction(messageToolBar: self)
        }
    }
}

// MARK: UITextViewDelegate

extension MessageToolbar: UITextViewDelegate {

    func textViewDidChange(textView: UITextView) {
        let text = textView.text

        if text.isEmpty {
            self.state = .Default
        } else {
            self.state = .TextInput
        }
    }
}

