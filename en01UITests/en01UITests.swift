//
//  en01UITests.swift
//  en01UITests
//
//  Created by tankoni TK on 2025/7/1.
//

import XCTest

final class en01UITests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        app = nil
    }

    @MainActor
    func testAppLaunchAndNavigation() throws {
        // 验证应用启动后主界面存在
        XCTAssertTrue(app.tabBars.firstMatch.exists)
        
        // 验证所有主要标签页存在
        XCTAssertTrue(app.tabBars.buttons["首页"].exists)
        XCTAssertTrue(app.tabBars.buttons["阅读"].exists)
        XCTAssertTrue(app.tabBars.buttons["词汇"].exists)
        XCTAssertTrue(app.tabBars.buttons["进度"].exists)
        XCTAssertTrue(app.tabBars.buttons["设置"].exists)
    }
    
    @MainActor
    func testHomeViewFunctionality() throws {
        // 确保在首页
        app.tabBars.buttons["首页"].tap()
        
        // 验证首页元素存在
        XCTAssertTrue(app.staticTexts["今日统计"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["推荐文章"].exists)
        XCTAssertTrue(app.staticTexts["最近阅读"].exists)
        
        // 测试搜索功能
        if app.searchFields.firstMatch.exists {
            app.searchFields.firstMatch.tap()
            app.searchFields.firstMatch.typeText("test")
            
            // 验证搜索结果显示
            XCTAssertTrue(app.collectionViews.firstMatch.exists)
        }
    }
    
    @MainActor
    func testReadingViewNavigation() throws {
        // 切换到阅读页面
        app.tabBars.buttons["阅读"].tap()
        
        // 验证阅读页面元素
        XCTAssertTrue(app.staticTexts["考研英语阅读"].waitForExistence(timeout: 5))
        
        // 测试年份选择
        if app.buttons["英语一"].exists {
            app.buttons["英语一"].tap()
            
            // 验证文章列表显示
            XCTAssertTrue(app.collectionViews.firstMatch.exists)
        }
        
        // 测试文章选择（如果有文章）
        let firstArticle = app.collectionViews.cells.firstMatch
        if firstArticle.exists {
            firstArticle.tap()
            
            // 验证文章阅读界面
            XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5))
        }
    }
    
    @MainActor
    func testVocabularyViewFunctionality() throws {
        // 切换到词汇页面
        app.tabBars.buttons["词汇"].tap()
        
        // 验证词汇页面元素
        XCTAssertTrue(app.staticTexts["我的词汇"].waitForExistence(timeout: 5))
        
        // 测试标签页切换
        if app.buttons["我的单词"].exists {
            app.buttons["我的单词"].tap()
            XCTAssertTrue(app.lists.firstMatch.exists)
        }
        
        if app.buttons["复习"].exists {
            app.buttons["复习"].tap()
            // 验证复习界面
        }
        
        if app.buttons["统计"].exists {
            app.buttons["统计"].tap()
            // 验证统计界面
        }
        
        // 测试搜索功能
        if app.searchFields.firstMatch.exists {
            app.searchFields.firstMatch.tap()
            app.searchFields.firstMatch.typeText("test")
        }
    }
    
    @MainActor
    // 原: testProgressViewDisplay()
    testProgressDashboardViewDisplay()
    // 更新函数名和内部引用
    func testProgressViewDisplay() throws {
        // 切换到进度页面
        app.tabBars.buttons["进度"].tap()
        
        // 验证进度页面元素
        XCTAssertTrue(app.staticTexts["学习进度"].waitForExistence(timeout: 5))
        
        // 验证统计卡片存在
        XCTAssertTrue(app.staticTexts["今日统计"].exists)
        XCTAssertTrue(app.staticTexts["本周统计"].exists)
        
        // 测试时间范围切换
        if app.buttons["本周"].exists {
            app.buttons["本周"].tap()
        }
        
        if app.buttons["本月"].exists {
            app.buttons["本月"].tap()
        }
    }
    
    @MainActor
    func testSettingsViewFunctionality() throws {
        // 切换到设置页面
        app.tabBars.buttons["设置"].tap()
        
        // 验证设置页面元素
        XCTAssertTrue(app.staticTexts["设置"].waitForExistence(timeout: 5))
        
        // 测试设置项点击
        if app.cells["阅读设置"].exists {
            app.cells["阅读设置"].tap()
            
            // 验证设置详情页面
            XCTAssertTrue(app.navigationBars.firstMatch.exists)
            
            // 返回
            if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
            }
        }
        
        // 测试其他设置项
        if app.cells["词汇设置"].exists {
            app.cells["词汇设置"].tap()
            
            if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
            }
        }
    }
    
    @MainActor
    func testArticleReadingFlow() throws {
        // 完整的文章阅读流程测试
        app.tabBars.buttons["阅读"].tap()
        
        // 选择英语一
        if app.buttons["英语一"].exists {
            app.buttons["英语一"].tap()
            
            // 选择第一篇文章
            let firstArticle = app.collectionViews.cells.firstMatch
            if firstArticle.waitForExistence(timeout: 5) {
                firstArticle.tap()
                
                // 验证文章阅读界面
                XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5))
                
                // 测试文本选择（模拟）
                let textView = app.scrollViews.firstMatch
                if textView.exists {
                    textView.swipeUp()
                    textView.swipeDown()
                }
                
                // 测试返回
                if app.navigationBars.buttons.firstMatch.exists {
                    app.navigationBars.buttons.firstMatch.tap()
                }
            }
        }
    }
    
    @MainActor
    func testVocabularyReviewFlow() throws {
        // 词汇复习流程测试
        app.tabBars.buttons["词汇"].tap()
        
        // 切换到复习标签
        if app.buttons["复习"].exists {
            app.buttons["复习"].tap()
            
            // 开始复习（如果有复习按钮）
            if app.buttons["开始复习"].exists {
                app.buttons["开始复习"].tap()
                
                // 模拟复习操作
                if app.buttons["认识"].exists {
                    app.buttons["认识"].tap()
                }
                
                if app.buttons["不认识"].exists {
                    app.buttons["不认识"].tap()
                }
            }
        }
    }
    
    @MainActor
    func testSearchFunctionality() throws {
        // 测试全局搜索功能
        app.tabBars.buttons["首页"].tap()
        
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("考研")
            
            // 验证搜索结果
            XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 3))
            
            // 清除搜索
            if app.buttons["Clear text"].exists {
                app.buttons["Clear text"].tap()
            }
        }
    }
    
    @MainActor
    func testAccessibilityElements() throws {
        // 测试无障碍功能
        app.tabBars.buttons["首页"].tap()
        
        // 验证主要元素有无障碍标识
        let homeTab = app.tabBars.buttons["首页"]
        XCTAssertTrue(homeTab.isAccessibilityElement)
        
        let readingTab = app.tabBars.buttons["阅读"]
        XCTAssertTrue(readingTab.isAccessibilityElement)
        
        let vocabularyTab = app.tabBars.buttons["词汇"]
        XCTAssertTrue(vocabularyTab.isAccessibilityElement)
        
        let progressTab = app.tabBars.buttons["进度"]
        XCTAssertTrue(progressTab.isAccessibilityElement)
        
        let settingsTab = app.tabBars.buttons["设置"]
        XCTAssertTrue(settingsTab.isAccessibilityElement)
    }
    
    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    @MainActor
    func testScrollPerformance() throws {
        // 测试滚动性能
        app.tabBars.buttons["阅读"].tap()
        
        if app.buttons["英语一"].exists {
            app.buttons["英语一"].tap()
            
            let collectionView = app.collectionViews.firstMatch
            if collectionView.waitForExistence(timeout: 5) {
                measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric]) {
                    collectionView.swipeUp()
                    collectionView.swipeDown()
                    collectionView.swipeUp()
                    collectionView.swipeDown()
                }
            }
        }
    }
    
    @MainActor
    func testMemoryWarningHandling() throws {
        // 模拟内存警告
        app.tabBars.buttons["首页"].tap()
        
        // 快速切换页面以增加内存压力
        for _ in 0..<10 {
            app.tabBars.buttons["阅读"].tap()
            app.tabBars.buttons["词汇"].tap()
            app.tabBars.buttons["进度"].tap()
            app.tabBars.buttons["设置"].tap()
            app.tabBars.buttons["首页"].tap()
        }
        
        // 验证应用仍然响应
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }
}
