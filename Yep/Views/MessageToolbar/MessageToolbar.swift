//
//  MessageToolbar.swift
//  Yep
//
//  Created by NIX on 15/3/24.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import Ruler

enum MessageToolbarState: Int, CustomStringConvertible {

    case Default
    case BeginTextInput
    case TextInputing
    case VoiceRecord

    var description: String {
        switch self {
        case .Default:
            return "Default"
        case .BeginTextInput:
            return "BeginTextInput"
        case .TextInputing:
            return "TextInputing"
        case .VoiceRecord:
            return "VoiceRecord"
        }
    }

    var isAtBottom: Bool {
        switch self {
        case .Default:
            return true
        case .BeginTextInput, .TextInputing:
            return false
        case .VoiceRecord:
            return true
        }
    }
}

@IBDesignable
class MessageToolbar: UIToolbar {
    
    var lastToolbarFrame: CGRect?

    var messageTextViewHeightConstraint: NSLayoutConstraint!
    let messageTextViewHeightConstraintNormalConstant: CGFloat = 34

    let messageTextAttributes = [NSFontAttributeName: UIFont.systemFontOfSize(15)]

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        finishNotifyTypingTimer?.invalidate()
    }

    struct Notification {
        static let updateDraft = "UpdateDraftOfConversation"
    }

    var conversation: Conversation? {
        willSet {
            if let _ = newValue {
                NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(MessageToolbar.updateDraft(_:)), name: Notification.updateDraft, object: nil)
            }
        }
    }

    var stateTransitionAction: ((messageToolbar: MessageToolbar, previousState: MessageToolbarState, currentState: MessageToolbarState) -> Void)?

    var previousState: MessageToolbarState = .Default
    var state: MessageToolbarState = .Default {
        willSet {

            updateHeightOfMessageTextView()

            previousState = state

            if let action = stateTransitionAction {
                action(messageToolbar: self, previousState: previousState, currentState: newValue)
            }

            switch newValue {
            case .Default:
                moreButton.hidden = false
                sendButton.hidden = true

                messageTextView.hidden = false
                voiceRecordButton.hidden = true

                micButton.setImage(UIImage(named: "item_mic"), forState: .Normal)
                moreButton.setImage(UIImage(named: "item_more"), forState: .Normal)

                micButton.tintColor = UIColor.messageToolBarColor()
                moreButton.tintColor = UIColor.messageToolBarColor()

                hideVoiceButtonAnimation()

            case .BeginTextInput:
                moreButton.hidden = false
                sendButton.hidden = true

                moreButton.setImage(UIImage(named: "item_more"), forState: .Normal)

            case .TextInputing:
                moreButton.hidden = true
                sendButton.hidden = false

                messageTextView.hidden = false
                voiceRecordButton.hidden = true
                
                notifyTyping()

            case .VoiceRecord:
                moreButton.hidden = false
                sendButton.hidden = true
                
                messageTextView.hidden = true
                voiceRecordButton.hidden = false

                messageTextView.text = nil

                micButton.setImage(UIImage(named: "icon_keyboard"), forState: .Normal)
                moreButton.setImage(UIImage(named: "item_more"), forState: .Normal)

                micButton.tintColor = UIColor.messageToolBarColor()
                moreButton.tintColor = UIColor.messageToolBarColor()

                showVoiceButtonAnimation()
            }
        }

        didSet {
            switch state {
            case .BeginTextInput, .TextInputing:
                // 由用户手动触发键盘弹出，回复时要注意
                break
            default:
                messageTextView.resignFirstResponder()
            }
        }
    }

    var notifyTypingAction: (() -> Void)?

    var needDetectMention = false
    var initMentionUserAction: (() -> Void)?
    var tryMentionUserAction: ((usernamePrefix: String) -> Void)?
    var giveUpMentionUserAction: (() -> Void)?

    var textSendAction: ((messageToolBar: MessageToolbar) -> Void)?

    var moreMessageTypesAction: (() -> Void)?

    var voiceRecordBeginAction: ((messageToolBar: MessageToolbar) -> Void)?
    var voiceRecordEndAction: ((messageToolBar: MessageToolbar) -> Void)?
    var voiceRecordCancelAction: ((messageToolBar: MessageToolbar) -> Void)?

    var voiceRecordingUpdateUIAction: ((topOffset: CGFloat) -> Void)?
    
    lazy var micButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "item_mic"), forState: .Normal)
        button.tintColor = UIColor.messageToolBarColor()
        button.tintAdjustmentMode = .Normal
        button.addTarget(self, action: #selector(MessageToolbar.toggleRecordVoice), forControlEvents: UIControlEvents.TouchUpInside)
        return button
    }()

    let normalCornerRadius: CGFloat = 6

    lazy var messageTextView: UITextView = {
        let textView = UITextView()
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.font = UIFont.systemFontOfSize(15)
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.yepMessageToolbarSubviewBorderColor().CGColor
        textView.layer.cornerRadius = self.normalCornerRadius
        textView.delegate = self
        textView.scrollEnabled = false // 重要：若没有它，换行时可能有 top inset 不正确
        return textView
    }()

    lazy var voiceRecordButton: VoiceRecordButton = {
        let button = VoiceRecordButton()

        button.backgroundColor = UIColor.whiteColor()
        button.layer.cornerRadius = self.normalCornerRadius
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.yepMessageToolbarSubviewBorderColor().CGColor
        button.tintColor = UIColor.messageToolBarHighlightColor()

        button.touchesBegin = { [weak self] in
            self?.tryVoiceRecordBegin()
        }

        button.touchesEnded = { [weak self] needAbort in
            if needAbort {
                self?.tryVoiceRecordCancel()
            } else {
                self?.tryVoiceRecordEnd()
            }
        }

        button.touchesCancelled = { [weak self] in
            self?.tryVoiceRecordCancel()
        }

        button.checkAbort = { [weak self] topOffset in
            self?.voiceRecordingUpdateUIAction?(topOffset: topOffset)

            return topOffset > 40
        }

        return button
    }()

    lazy var moreButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "item_more"), forState: .Normal)
        button.tintColor = UIColor.messageToolBarColor()
        button.tintAdjustmentMode = .Normal
        button.addTarget(self, action: #selector(MessageToolbar.moreMessageTypes), forControlEvents: UIControlEvents.TouchUpInside)
        return button
    }()

    lazy var sendButton: UIButton = {
        let button = UIButton()
        button.setTitle(NSLocalizedString("Send", comment: ""), forState: .Normal)
        button.tintColor = UIColor.messageToolBarHighlightColor()
        button.tintAdjustmentMode = .Normal
        button.setTitleColor(UIColor.messageToolBarHighlightColor(), forState: .Normal)
        button.addTarget(self, action: #selector(MessageToolbar.trySendTextMessage), forControlEvents: UIControlEvents.TouchUpInside)
        return button
    }()

    // MARK: UI
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        makeUI()

        state = .Default
    }

    func makeUI() {

        self.addSubview(messageTextView)
        messageTextView.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(micButton)
        micButton.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(voiceRecordButton)
        voiceRecordButton.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(moreButton)
        moreButton.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(sendButton)
        sendButton.translatesAutoresizingMaskIntoConstraints = false

        let viewsDictionary = [
            "moreButton": moreButton,
            "messageTextView": messageTextView,
            "micButton": micButton,
            "voiceRecordButton": voiceRecordButton,
            "sendButton": sendButton,
        ]

        let buttonBottom: CGFloat = 8
        let constraintsV1 = NSLayoutConstraint.constraintsWithVisualFormat("V:|-(>=0)-[micButton]-(bottom)-|", options: [], metrics: ["bottom": buttonBottom], views: viewsDictionary)
        let constraintsV2 = NSLayoutConstraint.constraintsWithVisualFormat("V:|-(>=0)-[moreButton(==micButton)]-(bottom)-|", options: [], metrics: ["bottom": buttonBottom], views: viewsDictionary)
        let constraintsV3 = NSLayoutConstraint.constraintsWithVisualFormat("V:|-(>=0)-[sendButton(==micButton)]-(bottom)-|", options: [], metrics: ["bottom": buttonBottom], views: viewsDictionary)

        let messageTextViewConstraintsV = NSLayoutConstraint.constraintsWithVisualFormat("V:|-7-[messageTextView]-8-|", options: [], metrics: nil, views: viewsDictionary)

        let textContainerInset = messageTextView.textContainerInset
        let constant = ceil(messageTextView.font!.lineHeight + textContainerInset.top + textContainerInset.bottom)
        //println("messageTextViewHeight: \(constant)")
        messageTextViewHeightConstraint = NSLayoutConstraint(item: messageTextView, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: constant)
        messageTextViewHeightConstraint.priority = UILayoutPriorityDefaultHigh

        let constraintsH = NSLayoutConstraint.constraintsWithVisualFormat("H:|[micButton(48)][messageTextView][moreButton(==micButton)]|", options: [], metrics: nil, views: viewsDictionary)

        NSLayoutConstraint.activateConstraints(constraintsV1)
        NSLayoutConstraint.activateConstraints(constraintsV2)
        NSLayoutConstraint.activateConstraints(constraintsV3)
        NSLayoutConstraint.activateConstraints(constraintsH)
        NSLayoutConstraint.activateConstraints(messageTextViewConstraintsV)
        NSLayoutConstraint.activateConstraints([messageTextViewHeightConstraint])

        let sendButtonConstraintCenterY = NSLayoutConstraint(item: sendButton, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: micButton, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: 0)

        let sendButtonConstraintHeight = NSLayoutConstraint(item: sendButton, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: micButton, attribute: NSLayoutAttribute.Height, multiplier: 1, constant: 0)

        let sendButtonConstraintsH = NSLayoutConstraint.constraintsWithVisualFormat("H:[messageTextView][sendButton(==moreButton)]|", options: [], metrics: nil, views: viewsDictionary)

        NSLayoutConstraint.activateConstraints([sendButtonConstraintCenterY])
        NSLayoutConstraint.activateConstraints([sendButtonConstraintHeight])
        NSLayoutConstraint.activateConstraints(sendButtonConstraintsH)

        // void record button
        let voiceRecordButtonConstraintsV = NSLayoutConstraint.constraintsWithVisualFormat("V:|-7-[voiceRecordButton]-8-|", options: [], metrics: nil, views: viewsDictionary)

        let voiceRecordButtonConstraintsH = NSLayoutConstraint.constraintsWithVisualFormat("H:|[micButton][voiceRecordButton][moreButton]|", options: [], metrics: nil, views: viewsDictionary)

        NSLayoutConstraint.activateConstraints(voiceRecordButtonConstraintsV)
        NSLayoutConstraint.activateConstraints(voiceRecordButtonConstraintsH)
    }

    // MARK: Animations

    func showVoiceButtonAnimation() {
        
        let animation = CABasicAnimation(keyPath: "cornerRadius")

        animation.fromValue = normalCornerRadius
        let newCornerRadius: CGFloat = 17
        animation.toValue = newCornerRadius
        animation.timingFunction = CAMediaTimingFunction(name: "easeInEaseOut")
        animation.repeatCount = 0

        voiceRecordButton.layer.addAnimation(animation, forKey: "cornerRadius")
        
        voiceRecordButton.layer.cornerRadius = newCornerRadius
        messageTextView.layer.cornerRadius = newCornerRadius

        UIView.animateWithDuration(0.1, delay: 0.0, options: .CurveEaseInOut, animations: { [weak self] in
            if let strongSelf = self {
                strongSelf.messageTextViewHeightConstraint.constant = strongSelf.messageTextViewHeightConstraintNormalConstant
                strongSelf.layoutIfNeeded()
            }
        }, completion: { _ in })
    }

    func hideVoiceButtonAnimation() {

        let animation = CABasicAnimation(keyPath: "cornerRadius")

        animation.fromValue = messageTextView.layer.cornerRadius
        animation.toValue = normalCornerRadius
        animation.repeatCount = 0
        
        animation.timingFunction = CAMediaTimingFunction(name: "easeInEaseOut")

        messageTextView.layer.addAnimation(animation, forKey: "cornerRadius")

        messageTextView.layer.cornerRadius = normalCornerRadius
        voiceRecordButton.layer.cornerRadius = normalCornerRadius
    }

    // Mark: Helpers

    func updateHeightOfMessageTextView() {

        let size = messageTextView.sizeThatFits(CGSize(width: CGRectGetWidth(messageTextView.bounds), height: CGFloat(FLT_MAX)))

        let newHeight = size.height
        let limitedNewHeight = min(Ruler.iPhoneVertical(60, 80, 100, 100).value, newHeight)

        //println("oldHeight: \(messageTextViewHeightConstraint.constant), newHeight: \(newHeight)")

        if newHeight != messageTextViewHeightConstraint.constant {

            UIView.animateWithDuration(0.1, delay: 0.0, options: .CurveEaseInOut, animations: {
                self.messageTextViewHeightConstraint.constant = limitedNewHeight
                self.layoutIfNeeded()

            }, completion: { [weak self] finished in
                // hack for scrollEnabled when input lots of text
                if finished, let strongSelf = self {
                    let enabled = newHeight > strongSelf.messageTextView.bounds.height
                    strongSelf.messageTextView.scrollEnabled = enabled
                }
            })
        }
    }

    // MARK: Actions

    func updateDraft(notification: NSNotification) {

        guard let conversation = conversation where !conversation.invalidated, let realm = conversation.realm else {
            return
        }

        if let draft = conversation.draft {

            let _ = try? realm.write { [weak self] in
                if let strongSelf = self {
                    draft.messageToolbarState = strongSelf.state.rawValue

                    //println("strongSelf.messageTextView.text: \(strongSelf.messageTextView.text)")
                    draft.text = strongSelf.messageTextView.text
                }
            }

        } else {
            let draft = Draft()
            draft.messageToolbarState = state.rawValue
            
            let _ = try? realm.write {
                conversation.draft = draft
            }
        }
    }

    func trySendTextMessage() {

        if let textSendAction = textSendAction {
            textSendAction(messageToolBar: self)
        }
    }

    func toggleRecordVoice() {

        if state == .VoiceRecord {
            state = .Default

        } else {
            state = .VoiceRecord
        }
    }

    func moreMessageTypes() {
        moreMessageTypesAction?()
    }

    private var mentionUsernameRange: Range<String.Index>?

    func replaceMentionedUsername(username: String) {

        defer {
            mentionUsernameRange = nil
        }

        guard !username.isEmpty else {
            return
        }

        let mentionUsernameWithSpaceSuffix = "@" + username + " "

        var text = messageTextView.text

        if let range = mentionUsernameRange {
            text.replaceRange(range, with: mentionUsernameWithSpaceSuffix)

            messageTextView.text = text

            updateHeightOfMessageTextView()
        }
    }

    func tryVoiceRecordBegin() {

        voiceRecordButton.state = .Touched

        voiceRecordBeginAction?(messageToolBar: self)
    }
    
    func tryVoiceRecordEnd() {

        voiceRecordButton.state = .Default

        voiceRecordEndAction?(messageToolBar: self)
    }
    
    func tryVoiceRecordCancel() {

        voiceRecordButton.state = .Default

        voiceRecordCancelAction?(messageToolBar: self)
    }
    
    // Notify typing

    private var finishNotifyTypingTimer: NSTimer?
    private var inNotifyTyping: Bool = false
    
    private func notifyTyping() {

        if inNotifyTyping {
            //println("inNotifyTyping")
            return

        } else {
            inNotifyTyping = true

            //println("notifyTypingAction")
            notifyTypingAction?()

            finishNotifyTypingTimer = NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: #selector(MessageToolbar.finishNotifyTyping(_:)), userInfo: nil, repeats: false)
        }
    }

    @objc private func finishNotifyTyping(sender: NSTimer) {
        inNotifyTyping = false
    }
}

// MARK: UITextViewDelegate

extension MessageToolbar: UITextViewDelegate {

    func textViewDidBeginEditing(textView: UITextView) {

        guard let text = textView.text else { return }

        state = text.isEmpty ? .BeginTextInput : .TextInputing
    }

    func textViewDidChange(textView: UITextView) {

        guard let text = textView.text else { return }

        state = text.isEmpty ? .BeginTextInput : .TextInputing

        if needDetectMention {

            // 刚刚输入 @

            if text.hasSuffix("@") {
                mentionUsernameRange = text.endIndex.advancedBy(-1)..<text.endIndex
                initMentionUserAction?()
                return
            }

            // 对于拼音输入法等，输入时会先显示拼音，然后才上字，拼音间有空格（这个空格似乎不是普通空格）

            if let markedTextRange = textView.markedTextRange, markedText = textView.textInRange(markedTextRange) {

                var text = text

                let beginning = textView.beginningOfDocument
                let start = markedTextRange.start
                let end = markedTextRange.end
                let location = textView.offsetFromPosition(beginning, toPosition: start)

                // 保证前面至少还有一个字符，for mentionNSRange
                guard location > 0 else {
                    return
                }

                let length = textView.offsetFromPosition(start, toPosition: end)
                let nsRange = NSMakeRange(location, length)
                let mentionNSRange = NSMakeRange(location - 1, length + 1)
                guard let range = text.yep_rangeFromNSRange(nsRange), mentionRange = text.yep_rangeFromNSRange(mentionNSRange) else {
                    return
                }

                text.removeRange(range)

                if text.hasSuffix("@") {
                    mentionUsernameRange = mentionRange

                    let wordString = markedText.yep_removeAllWhitespaces
                    println("wordString from markedText: >\(wordString)<")
                    tryMentionUserAction?(usernamePrefix: wordString)

                    return
                }
            }

            // 正常查询 mention

            let currentLetterIndex = textView.selectedRange.location - 1

            if let (wordString, mentionWordRange) = text.yep_mentionWordInIndex(currentLetterIndex) {
                //println("mentionWord: \(wordString), \(mentionWordRange)")

                mentionUsernameRange = mentionWordRange

                let wordString = wordString.trimming(.Whitespace)
                tryMentionUserAction?(usernamePrefix: wordString)

                return
            }

            // 都没有就放弃

            giveUpMentionUserAction?()
        }
    }
}

