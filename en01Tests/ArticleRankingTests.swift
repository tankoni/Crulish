//
//  ArticleRankingTests.swift
//  en01Tests
//
//  Created by SOLO Coding on 2025/01/20.
//

import XCTest
@testable import en01

final class ArticleRankingTests: XCTestCase {
    
    var articleRanking: ArticleRanking!
    
    override func setUpWithError() throws {
        super.setUp()
        
        let vocabularyAnalysis = VocabularyAnalysis(
            totalWords: 500,
            unknownWords: 50,
            familiarWords: 200,
            masteredWords: 200,
            newWords: 50
        )
        
        let difficultyAssessment = DifficultyAssessment(
            estimatedDifficulty: 3.5,
            estimatedReadingTime: 15.0,
            vocabularyLevelRequired: .intermediate
        )
        
        let learningValueAssessment = LearningValueAssessment(
            learningValue: 0.8,
            vocabularyGrowthPotential: 0.7,
            reviewValue: 0.6
        )
        
        let rankingWeights = RankingWeights(
            vocabularyWeight: 0.4,
            difficultyWeight: 0.3,
            priorityWeight: 0.2,
            preferenceWeight: 0.1
        )
        
        articleRanking = ArticleRanking(
            articleId: "test-article-001",
            title: "Test Article Title",
            overallScore: 0.0, // 将通过计算得出
            vocabularyMatchScore: 0.0, // 将通过计算得出
            difficultyFitScore: 0.0, // 将通过计算得出
            priorityScore: 0.0, // 将通过计算得出
            vocabularyAnalysis: vocabularyAnalysis,
            difficultyAssessment: difficultyAssessment,
            learningValueAssessment: learningValueAssessment,
            rankingWeights: rankingWeights,
            userPreferenceMatch: 0.75,
            lastRankedDate: Date(),
            isRecommended: false
        )
    }
    
    override func tearDownWithError() throws {
        articleRanking = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testArticleRankingInitialization() {
        XCTAssertEqual(articleRanking.articleId, "test-article-001")
        XCTAssertEqual(articleRanking.title, "Test Article Title")
        XCTAssertEqual(articleRanking.vocabularyAnalysis.totalWords, 500)
        XCTAssertEqual(articleRanking.difficultyAssessment.vocabularyLevelRequired, .intermediate)
        XCTAssertEqual(articleRanking.userPreferenceMatch, 0.75)
        XCTAssertFalse(articleRanking.isRecommended)
    }
    
    func testVocabularyAnalysisInitialization() {
        let analysis = articleRanking.vocabularyAnalysis
        
        XCTAssertEqual(analysis.totalWords, 500)
        XCTAssertEqual(analysis.unknownWords, 50)
        XCTAssertEqual(analysis.familiarWords, 200)
        XCTAssertEqual(analysis.masteredWords, 200)
        XCTAssertEqual(analysis.newWords, 50)
    }
    
    func testDifficultyAssessmentInitialization() {
        let assessment = articleRanking.difficultyAssessment
        
        XCTAssertEqual(assessment.estimatedDifficulty, 3.5)
        XCTAssertEqual(assessment.estimatedReadingTime, 15.0)
        XCTAssertEqual(assessment.vocabularyLevelRequired, .intermediate)
    }
    
    func testLearningValueAssessmentInitialization() {
        let assessment = articleRanking.learningValueAssessment
        
        XCTAssertEqual(assessment.learningValue, 0.8)
        XCTAssertEqual(assessment.vocabularyGrowthPotential, 0.7)
        XCTAssertEqual(assessment.reviewValue, 0.6)
    }
    
    func testRankingWeightsInitialization() {
        let weights = articleRanking.rankingWeights
        
        XCTAssertEqual(weights.vocabularyWeight, 0.4)
        XCTAssertEqual(weights.difficultyWeight, 0.3)
        XCTAssertEqual(weights.priorityWeight, 0.2)
        XCTAssertEqual(weights.preferenceWeight, 0.1)
        
        // 检查权重总和是否为1.0
        let totalWeight = weights.vocabularyWeight + weights.difficultyWeight + 
                         weights.priorityWeight + weights.preferenceWeight
        XCTAssertEqual(totalWeight, 1.0, accuracy: 0.001)
    }
    
    // MARK: - Score Calculation Tests
    
    func testCalculateOverallScore() {
        let userVocabularyLevel: VocabularyLevel = .intermediate
        let strategy: RankingStrategy = .balanced
        
        let score = articleRanking.calculateOverallScore(
            userVocabularyLevel: userVocabularyLevel,
            strategy: strategy
        )
        
        XCTAssertGreaterThanOrEqual(score, 0.0)
        XCTAssertLessThanOrEqual(score, 1.0)
        
        // 验证分数已更新
        XCTAssertEqual(articleRanking.overallScore, score)
    }
    
    func testCalculateVocabularyMatchScore() {
        let userVocabularyLevel: VocabularyLevel = .intermediate
        
        let score = articleRanking.calculateVocabularyMatchScore(userVocabularyLevel: userVocabularyLevel)
        
        XCTAssertGreaterThanOrEqual(score, 0.0)
        XCTAssertLessThanOrEqual(score, 1.0)
        
        // 验证分数已更新
        XCTAssertEqual(articleRanking.vocabularyMatchScore, score)
    }
    
    func testCalculateDifficultyFitScore() {
        let userVocabularyLevel: VocabularyLevel = .intermediate
        
        let score = articleRanking.calculateDifficultyFitScore(userVocabularyLevel: userVocabularyLevel)
        
        XCTAssertGreaterThanOrEqual(score, 0.0)
        XCTAssertLessThanOrEqual(score, 1.0)
        
        // 验证分数已更新
        XCTAssertEqual(articleRanking.difficultyFitScore, score)
    }
    
    func testCalculatePriorityScore() {
        let strategy: RankingStrategy = .vocabularyFirst
        
        let score = articleRanking.calculatePriorityScore(strategy: strategy)
        
        XCTAssertGreaterThanOrEqual(score, 0.0)
        XCTAssertLessThanOrEqual(score, 1.0)
        
        // 验证分数已更新
        XCTAssertEqual(articleRanking.priorityScore, score)
    }
    
    func testCalculateLearningValue() {
        let userVocabularyLevel: VocabularyLevel = .intermediate
        
        let value = articleRanking.calculateLearningValue(userVocabularyLevel: userVocabularyLevel)
        
        XCTAssertGreaterThanOrEqual(value, 0.0)
        XCTAssertLessThanOrEqual(value, 1.0)
        
        // 验证学习价值已更新
        XCTAssertEqual(articleRanking.learningValueAssessment.learningValue, value)
    }
    
    func testCalculateVocabularyGrowthPotential() {
        let userVocabularyLevel: VocabularyLevel = .intermediate
        
        let potential = articleRanking.calculateVocabularyGrowthPotential(userVocabularyLevel: userVocabularyLevel)
        
        XCTAssertGreaterThanOrEqual(potential, 0.0)
        XCTAssertLessThanOrEqual(potential, 1.0)
        
        // 验证词汇增长潜力已更新
        XCTAssertEqual(articleRanking.learningValueAssessment.vocabularyGrowthPotential, potential)
    }
    
    func testCalculateReviewValue() {
        let userVocabularyLevel: VocabularyLevel = .intermediate
        
        let value = articleRanking.calculateReviewValue(userVocabularyLevel: userVocabularyLevel)
        
        XCTAssertGreaterThanOrEqual(value, 0.0)
        XCTAssertLessThanOrEqual(value, 1.0)
        
        // 验证复习价值已更新
        XCTAssertEqual(articleRanking.learningValueAssessment.reviewValue, value)
    }
    
    // MARK: - Strategy Tests
    
    func testDifferentRankingStrategies() {
        let userVocabularyLevel: VocabularyLevel = .intermediate
        
        let strategies: [RankingStrategy] = [.vocabularyFirst, .difficultyFirst, .balanced, .learningFirst, .reviewFirst]
        var scores: [Double] = []
        
        for strategy in strategies {
            let score = articleRanking.calculateOverallScore(
                userVocabularyLevel: userVocabularyLevel,
                strategy: strategy
            )
            scores.append(score)
        }
        
        // 验证不同策略产生不同的分数
        let uniqueScores = Set(scores.map { String(format: "%.3f", $0) })
        XCTAssertGreaterThan(uniqueScores.count, 1, "不同策略应该产生不同的分数")
    }
    
    func testVocabularyFirstStrategy() {
        let userVocabularyLevel: VocabularyLevel = .intermediate
        
        // 创建两个文章排序，一个词汇匹配度更高
        let highVocabArticle = createTestArticle(unknownWords: 20, familiarWords: 300)
        let lowVocabArticle = createTestArticle(unknownWords: 100, familiarWords: 200)
        
        let highScore = highVocabArticle.calculateOverallScore(
            userVocabularyLevel: userVocabularyLevel,
            strategy: .vocabularyFirst
        )
        
        let lowScore = lowVocabArticle.calculateOverallScore(
            userVocabularyLevel: userVocabularyLevel,
            strategy: .vocabularyFirst
        )
        
        XCTAssertGreaterThan(highScore, lowScore, "词汇优先策略下，词汇匹配度高的文章应该得分更高")
    }
    
    func testDifficultyFirstStrategy() {
        let userVocabularyLevel: VocabularyLevel = .intermediate
        
        // 创建两个文章排序，一个难度更适合
        let appropriateDifficultyArticle = createTestArticle(difficulty: 3.0) // 适合中级
        let inappropriateDifficultyArticle = createTestArticle(difficulty: 1.0) // 太简单
        
        let appropriateScore = appropriateDifficultyArticle.calculateOverallScore(
            userVocabularyLevel: userVocabularyLevel,
            strategy: .difficultyFirst
        )
        
        let inappropriateScore = inappropriateDifficultyArticle.calculateOverallScore(
            userVocabularyLevel: userVocabularyLevel,
            strategy: .difficultyFirst
        )
        
        XCTAssertGreaterThan(appropriateScore, inappropriateScore, "难度优先策略下，难度适合的文章应该得分更高")
    }
    
    // MARK: - Vocabulary Level Tests
    
    func testVocabularyLevelMatching() {
        let levels: [VocabularyLevel] = [.beginner, .intermediate, .advanced, .expert]
        
        for level in levels {
            let score = articleRanking.calculateVocabularyMatchScore(userVocabularyLevel: level)
            XCTAssertGreaterThanOrEqual(score, 0.0)
            XCTAssertLessThanOrEqual(score, 1.0)
        }
    }
    
    func testVocabularyLevelDifficultyFit() {
        // 测试不同词汇水平对难度适配的影响
        let beginnerScore = articleRanking.calculateDifficultyFitScore(userVocabularyLevel: .beginner)
        let expertScore = articleRanking.calculateDifficultyFitScore(userVocabularyLevel: .expert)
        
        // 对于中等难度的文章，初学者和专家的适配分数应该不同
        XCTAssertNotEqual(beginnerScore, expertScore)
    }
    
    // MARK: - Recommendation Tests
    
    func testUpdateRecommendationStatus() {
        let userVocabularyLevel: VocabularyLevel = .intermediate
        let strategy: RankingStrategy = .balanced
        let threshold: Double = 0.7
        
        articleRanking.updateRecommendationStatus(
            userVocabularyLevel: userVocabularyLevel,
            strategy: strategy,
            threshold: threshold
        )
        
        // 验证推荐状态已更新
        let expectedRecommendation = articleRanking.overallScore >= threshold
        XCTAssertEqual(articleRanking.isRecommended, expectedRecommendation)
    }
    
    func testHighScoreRecommendation() {
        // 创建一个高分文章
        let highScoreArticle = createTestArticle(unknownWords: 30, familiarWords: 400, difficulty: 3.0)
        
        highScoreArticle.updateRecommendationStatus(
            userVocabularyLevel: .intermediate,
            strategy: .balanced,
            threshold: 0.5
        )
        
        XCTAssertTrue(highScoreArticle.isRecommended, "高分文章应该被推荐")
    }
    
    func testLowScoreNotRecommended() {
        // 创建一个低分文章
        let lowScoreArticle = createTestArticle(unknownWords: 400, familiarWords: 50, difficulty: 5.0)
        
        lowScoreArticle.updateRecommendationStatus(
            userVocabularyLevel: .intermediate,
            strategy: .balanced,
            threshold: 0.7
        )
        
        XCTAssertFalse(lowScoreArticle.isRecommended, "低分文章不应该被推荐")
    }
    
    // MARK: - Codable Tests
    
    func testArticleRankingCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // 编码
        let encodedData = try encoder.encode(articleRanking)
        XCTAssertGreaterThan(encodedData.count, 0)
        
        // 解码
        let decodedArticleRanking = try decoder.decode(ArticleRanking.self, from: encodedData)
        
        // 验证解码结果
        XCTAssertEqual(decodedArticleRanking.articleId, articleRanking.articleId)
        XCTAssertEqual(decodedArticleRanking.title, articleRanking.title)
        XCTAssertEqual(decodedArticleRanking.vocabularyAnalysis.totalWords, articleRanking.vocabularyAnalysis.totalWords)
        XCTAssertEqual(decodedArticleRanking.difficultyAssessment.estimatedDifficulty, articleRanking.difficultyAssessment.estimatedDifficulty)
        XCTAssertEqual(decodedArticleRanking.userPreferenceMatch, articleRanking.userPreferenceMatch)
    }
    
    func testVocabularyLevelCodable() throws {
        let levels: [VocabularyLevel] = [.beginner, .intermediate, .advanced, .expert]
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for level in levels {
            let encodedData = try encoder.encode(level)
            let decodedLevel = try decoder.decode(VocabularyLevel.self, from: encodedData)
            XCTAssertEqual(decodedLevel, level)
        }
    }
    
    func testRankingStrategyCodable() throws {
        let strategies: [RankingStrategy] = [.vocabularyFirst, .difficultyFirst, .balanced, .learningFirst, .reviewFirst]
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for strategy in strategies {
            let encodedData = try encoder.encode(strategy)
            let decodedStrategy = try decoder.decode(RankingStrategy.self, from: encodedData)
            XCTAssertEqual(decodedStrategy, strategy)
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testZeroWordsArticle() {
        let zeroWordsAnalysis = VocabularyAnalysis(
            totalWords: 0,
            unknownWords: 0,
            familiarWords: 0,
            masteredWords: 0,
            newWords: 0
        )
        
        let zeroWordsArticle = ArticleRanking(
            articleId: "zero-words",
            title: "Empty Article",
            overallScore: 0.0,
            vocabularyMatchScore: 0.0,
            difficultyFitScore: 0.0,
            priorityScore: 0.0,
            vocabularyAnalysis: zeroWordsAnalysis,
            difficultyAssessment: articleRanking.difficultyAssessment,
            learningValueAssessment: articleRanking.learningValueAssessment,
            rankingWeights: articleRanking.rankingWeights,
            userPreferenceMatch: 0.0,
            lastRankedDate: Date(),
            isRecommended: false
        )
        
        let score = zeroWordsArticle.calculateOverallScore(
            userVocabularyLevel: .intermediate,
            strategy: .balanced
        )
        
        XCTAssertGreaterThanOrEqual(score, 0.0)
        XCTAssertLessThanOrEqual(score, 1.0)
    }
    
    func testExtremeValues() {
        // 测试极端值情况
        let extremeAnalysis = VocabularyAnalysis(
            totalWords: 10000,
            unknownWords: 10000,
            familiarWords: 0,
            masteredWords: 0,
            newWords: 10000
        )
        
        let extremeAssessment = DifficultyAssessment(
            estimatedDifficulty: 5.0,
            estimatedReadingTime: 120.0,
            vocabularyLevelRequired: .expert
        )
        
        let extremeArticle = ArticleRanking(
            articleId: "extreme",
            title: "Extreme Article",
            overallScore: 0.0,
            vocabularyMatchScore: 0.0,
            difficultyFitScore: 0.0,
            priorityScore: 0.0,
            vocabularyAnalysis: extremeAnalysis,
            difficultyAssessment: extremeAssessment,
            learningValueAssessment: articleRanking.learningValueAssessment,
            rankingWeights: articleRanking.rankingWeights,
            userPreferenceMatch: 1.0,
            lastRankedDate: Date(),
            isRecommended: false
        )
        
        let score = extremeArticle.calculateOverallScore(
            userVocabularyLevel: .beginner,
            strategy: .balanced
        )
        
        XCTAssertGreaterThanOrEqual(score, 0.0)
        XCTAssertLessThanOrEqual(score, 1.0)
    }
    
    // MARK: - Performance Tests
    
    func testCalculationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = articleRanking.calculateOverallScore(
                    userVocabularyLevel: .intermediate,
                    strategy: .balanced
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestArticle(
        unknownWords: Int = 50,
        familiarWords: Int = 200,
        masteredWords: Int = 200,
        newWords: Int = 50,
        difficulty: Double = 3.5
    ) -> ArticleRanking {
        let totalWords = unknownWords + familiarWords + masteredWords + newWords
        
        let vocabularyAnalysis = VocabularyAnalysis(
            totalWords: totalWords,
            unknownWords: unknownWords,
            familiarWords: familiarWords,
            masteredWords: masteredWords,
            newWords: newWords
        )
        
        let difficultyAssessment = DifficultyAssessment(
            estimatedDifficulty: difficulty,
            estimatedReadingTime: Double(totalWords) / 200.0 * 60.0, // 假设每分钟200词
            vocabularyLevelRequired: difficulty < 2.0 ? .beginner :
                                   difficulty < 3.5 ? .intermediate :
                                   difficulty < 4.5 ? .advanced : .expert
        )
        
        let learningValueAssessment = LearningValueAssessment(
            learningValue: 0.8,
            vocabularyGrowthPotential: 0.7,
            reviewValue: 0.6
        )
        
        let rankingWeights = RankingWeights(
            vocabularyWeight: 0.4,
            difficultyWeight: 0.3,
            priorityWeight: 0.2,
            preferenceWeight: 0.1
        )
        
        return ArticleRanking(
            articleId: UUID().uuidString,
            title: "Test Article",
            overallScore: 0.0,
            vocabularyMatchScore: 0.0,
            difficultyFitScore: 0.0,
            priorityScore: 0.0,
            vocabularyAnalysis: vocabularyAnalysis,
            difficultyAssessment: difficultyAssessment,
            learningValueAssessment: learningValueAssessment,
            rankingWeights: rankingWeights,
            userPreferenceMatch: 0.75,
            lastRankedDate: Date(),
            isRecommended: false
        )
    }
}