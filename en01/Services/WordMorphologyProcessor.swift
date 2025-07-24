//
//  WordMorphologyProcessor.swift
//  en01
//
//  Created by Solo Coding on 2024/12/19.
//

import Foundation

/// 词形变化处理器，用于处理单词的各种形态变化
class WordMorphologyProcessor {
    
    /// 单例实例
    static let shared = WordMorphologyProcessor()
    
    private init() {}
    
    /// 获取单词的所有可能形态
    /// - Parameter word: 输入单词
    /// - Returns: 包含原词和所有可能变形的数组
    func getAllPossibleForms(for word: String) -> [String] {
        let lowercaseWord = word.lowercased()
        var forms = Set<String>()
        
        // 添加原词
        forms.insert(lowercaseWord)
        forms.insert(word) // 保留原始大小写
        
        // 获取词根形式
        let stemForms = getStemForms(for: lowercaseWord)
        forms.formUnion(stemForms)
        
        // 获取派生形式
        let derivedForms = getDerivedForms(for: lowercaseWord)
        forms.formUnion(derivedForms)
        
        return Array(forms)
    }
    
    /// 获取词根形式（去除后缀）
    private func getStemForms(for word: String) -> Set<String> {
        var forms = Set<String>()
        
        // 处理复数形式
        forms.formUnion(handlePluralForms(word))
        
        // 处理动词变形
        forms.formUnion(handleVerbForms(word))
        
        // 处理形容词和副词变形
        forms.formUnion(handleAdjectiveAdverbForms(word))
        
        return forms
    }
    
    /// 获取派生形式（添加后缀）
    private func getDerivedForms(for word: String) -> Set<String> {
        var forms = Set<String>()
        
        // 生成复数形式
        forms.formUnion(generatePluralForms(word))
        
        // 生成动词变形
        forms.formUnion(generateVerbForms(word))
        
        // 生成形容词和副词变形
        forms.formUnion(generateAdjectiveAdverbForms(word))
        
        return forms
    }
    
    // MARK: - 复数形式处理
    
    private func handlePluralForms(_ word: String) -> Set<String> {
        var forms = Set<String>()
        
        // 规则复数 -> 单数
        if word.hasSuffix("s") {
            let singular = String(word.dropLast())
            if singular.count > 2 {
                forms.insert(singular)
            }
        }
        
        // -es 结尾
        if word.hasSuffix("es") {
            let base = String(word.dropLast(2))
            if base.count > 2 {
                forms.insert(base)
                // 处理 -ies -> -y
                if word.hasSuffix("ies") {
                    let yForm = String(word.dropLast(3)) + "y"
                    forms.insert(yForm)
                }
            }
        }
        
        // 不规则复数
        let irregularPlurals = [
            "children": "child",
            "feet": "foot",
            "teeth": "tooth",
            "men": "man",
            "women": "woman",
            "mice": "mouse",
            "geese": "goose"
        ]
        
        if let singular = irregularPlurals[word] {
            forms.insert(singular)
        }
        
        return forms
    }
    
    private func generatePluralForms(_ word: String) -> Set<String> {
        var forms = Set<String>()
        
        // 规则复数
        forms.insert(word + "s")
        
        // -es 复数（以 s, x, z, ch, sh 结尾）
        if word.hasSuffix("s") || word.hasSuffix("x") || word.hasSuffix("z") ||
           word.hasSuffix("ch") || word.hasSuffix("sh") {
            forms.insert(word + "es")
        }
        
        // -y -> -ies
        if word.hasSuffix("y") && word.count > 1 {
            let beforeY = word[word.index(word.endIndex, offsetBy: -2)]
            if !"aeiou".contains(beforeY) {
                let base = String(word.dropLast())
                forms.insert(base + "ies")
            }
        }
        
        // -f/-fe -> -ves
        if word.hasSuffix("f") {
            let base = String(word.dropLast())
            forms.insert(base + "ves")
        } else if word.hasSuffix("fe") {
            let base = String(word.dropLast(2))
            forms.insert(base + "ves")
        }
        
        return forms
    }
    
    // MARK: - 动词形式处理
    
    private func handleVerbForms(_ word: String) -> Set<String> {
        var forms = Set<String>()
        
        // -ed 过去式/过去分词 -> 原形
        if word.hasSuffix("ed") {
            let base = String(word.dropLast(2))
            if base.count > 2 {
                forms.insert(base)
                // 处理双写辅音字母的情况
                if base.count > 1 && base.last == base[base.index(base.endIndex, offsetBy: -2)] {
                    let singleConsonant = String(base.dropLast())
                    forms.insert(singleConsonant)
                }
            }
        }
        
        // -ing 现在分词 -> 原形
        if word.hasSuffix("ing") {
            let base = String(word.dropLast(3))
            if base.count > 2 {
                forms.insert(base)
                forms.insert(base + "e") // 可能去掉了 e
                // 处理双写辅音字母的情况
                if base.count > 1 && base.last == base[base.index(base.endIndex, offsetBy: -2)] {
                    let singleConsonant = String(base.dropLast())
                    forms.insert(singleConsonant)
                }
            }
        }
        
        // -s 第三人称单数 -> 原形
        if word.hasSuffix("s") && !word.hasSuffix("ss") {
            let base = String(word.dropLast())
            if base.count > 2 {
                forms.insert(base)
            }
        }
        
        // 不规则动词
        let irregularVerbs = [
            "was": "be", "were": "be", "been": "be",
            "had": "have", "has": "have",
            "did": "do", "done": "do", "does": "do",
            "went": "go", "gone": "go", "goes": "go",
            "came": "come", "comes": "come",
            "saw": "see", "seen": "see", "sees": "see",
            "took": "take", "taken": "take", "takes": "take",
            "got": "get", "gotten": "get", "gets": "get",
            "made": "make", "makes": "make",
            "said": "say", "says": "say",
            "thought": "think", "thinks": "think",
            "knew": "know", "known": "know", "knows": "know",
            "found": "find", "finds": "find",
            "gave": "give", "given": "give", "gives": "give",
            "told": "tell", "tells": "tell",
            "felt": "feel", "feels": "feel",
            "left": "leave", "leaves": "leave",
            "kept": "keep", "keeps": "keep",
            "held": "hold", "holds": "hold",
            "brought": "bring", "brings": "bring",
            "built": "build", "builds": "build",
            "bought": "buy", "buys": "buy",
            "caught": "catch", "catches": "catch",
            "chose": "choose", "chosen": "choose", "chooses": "choose",
            "cut": "cut", "cuts": "cut",
            "drew": "draw", "drawn": "draw", "draws": "draw",
            "drove": "drive", "driven": "drive", "drives": "drive",
            "ate": "eat", "eaten": "eat", "eats": "eat",
            "fell": "fall", "fallen": "fall", "falls": "fall",
            "flew": "fly", "flown": "fly", "flies": "fly",
            "forgot": "forget", "forgotten": "forget", "forgets": "forget",
            "grew": "grow", "grown": "grow", "grows": "grow",
            "heard": "hear", "hears": "hear",
            "hid": "hide", "hidden": "hide", "hides": "hide",
            "lay": "lie", "lain": "lie", "lies": "lie",
            "lost": "lose", "loses": "lose",
            "met": "meet", "meets": "meet",
            "paid": "pay", "pays": "pay",
            "put": "put", "puts": "put",
            "ran": "run", "runs": "run",
            "sang": "sing", "sung": "sing", "sings": "sing",
            "sat": "sit", "sits": "sit",
            "slept": "sleep", "sleeps": "sleep",
            "spoke": "speak", "spoken": "speak", "speaks": "speak",
            "spent": "spend", "spends": "spend",
            "stood": "stand", "stands": "stand",
            "swam": "swim", "swum": "swim", "swims": "swim",
            "taught": "teach", "teaches": "teach",
            "threw": "throw", "thrown": "throw", "throws": "throw",
            "understood": "understand", "understands": "understand",
            "woke": "wake", "woken": "wake", "wakes": "wake",
            "wore": "wear", "worn": "wear", "wears": "wear",
            "won": "win", "wins": "win",
            "wrote": "write", "written": "write", "writes": "write"
        ]
        
        if let baseForm = irregularVerbs[word] {
            forms.insert(baseForm)
        }
        
        return forms
    }
    
    private func generateVerbForms(_ word: String) -> Set<String> {
        var forms = Set<String>()
        
        // 第三人称单数
        if word.hasSuffix("s") || word.hasSuffix("x") || word.hasSuffix("z") ||
           word.hasSuffix("ch") || word.hasSuffix("sh") {
            forms.insert(word + "es")
        } else if word.hasSuffix("y") && word.count > 1 {
            let beforeY = word[word.index(word.endIndex, offsetBy: -2)]
            if !"aeiou".contains(beforeY) {
                let base = String(word.dropLast())
                forms.insert(base + "ies")
            } else {
                forms.insert(word + "s")
            }
        } else {
            forms.insert(word + "s")
        }
        
        // 过去式和过去分词 (-ed)
        if word.hasSuffix("e") {
            forms.insert(word + "d")
        } else if word.hasSuffix("y") && word.count > 1 {
            let beforeY = word[word.index(word.endIndex, offsetBy: -2)]
            if !"aeiou".contains(beforeY) {
                let base = String(word.dropLast())
                forms.insert(base + "ied")
            } else {
                forms.insert(word + "ed")
            }
        } else if shouldDoubleConsonant(word) {
            forms.insert(word + word.suffix(1) + "ed")
        } else {
            forms.insert(word + "ed")
        }
        
        // 现在分词 (-ing)
        if word.hasSuffix("e") && !word.hasSuffix("ee") && !word.hasSuffix("ie") {
            let base = String(word.dropLast())
            forms.insert(base + "ing")
        } else if word.hasSuffix("ie") {
            let base = String(word.dropLast(2))
            forms.insert(base + "ying")
        } else if shouldDoubleConsonant(word) {
            forms.insert(word + word.suffix(1) + "ing")
        } else {
            forms.insert(word + "ing")
        }
        
        return forms
    }
    
    // MARK: - 形容词和副词形式处理
    
    private func handleAdjectiveAdverbForms(_ word: String) -> Set<String> {
        var forms = Set<String>()
        
        // -ly 副词 -> 形容词
        if word.hasSuffix("ly") {
            let base = String(word.dropLast(2))
            if base.count > 2 {
                forms.insert(base)
                // 处理 -ily -> -y
                if word.hasSuffix("ily") {
                    let yForm = String(word.dropLast(3)) + "y"
                    forms.insert(yForm)
                }
            }
        }
        
        // 比较级和最高级 -> 原级
        if word.hasSuffix("er") {
            let base = String(word.dropLast(2))
            if base.count > 2 {
                forms.insert(base)
                // 处理双写辅音字母的情况
                if base.count > 1 && base.last == base[base.index(base.endIndex, offsetBy: -2)] {
                    let singleConsonant = String(base.dropLast())
                    forms.insert(singleConsonant)
                }
            }
        }
        
        if word.hasSuffix("est") {
            let base = String(word.dropLast(3))
            if base.count > 2 {
                forms.insert(base)
                // 处理双写辅音字母的情况
                if base.count > 1 && base.last == base[base.index(base.endIndex, offsetBy: -2)] {
                    let singleConsonant = String(base.dropLast())
                    forms.insert(singleConsonant)
                }
            }
        }
        
        return forms
    }
    
    private func generateAdjectiveAdverbForms(_ word: String) -> Set<String> {
        var forms = Set<String>()
        
        // 副词形式 (-ly)
        if word.hasSuffix("y") {
            let base = String(word.dropLast())
            forms.insert(base + "ily")
        } else if word.hasSuffix("le") {
            let base = String(word.dropLast(2))
            forms.insert(base + "ly")
        } else if word.hasSuffix("ic") {
            forms.insert(word + "ally")
        } else {
            forms.insert(word + "ly")
        }
        
        // 比较级 (-er)
        if word.hasSuffix("e") {
            forms.insert(word + "r")
        } else if word.hasSuffix("y") && word.count > 1 {
            let beforeY = word[word.index(word.endIndex, offsetBy: -2)]
            if !"aeiou".contains(beforeY) {
                let base = String(word.dropLast())
                forms.insert(base + "ier")
            } else {
                forms.insert(word + "er")
            }
        } else if shouldDoubleConsonant(word) {
            forms.insert(word + word.suffix(1) + "er")
        } else {
            forms.insert(word + "er")
        }
        
        // 最高级 (-est)
        if word.hasSuffix("e") {
            forms.insert(word + "st")
        } else if word.hasSuffix("y") && word.count > 1 {
            let beforeY = word[word.index(word.endIndex, offsetBy: -2)]
            if !"aeiou".contains(beforeY) {
                let base = String(word.dropLast())
                forms.insert(base + "iest")
            } else {
                forms.insert(word + "est")
            }
        } else if shouldDoubleConsonant(word) {
            forms.insert(word + word.suffix(1) + "est")
        } else {
            forms.insert(word + "est")
        }
        
        return forms
    }
    
    // MARK: - 辅助方法
    
    /// 判断是否需要双写辅音字母
    private func shouldDoubleConsonant(_ word: String) -> Bool {
        guard word.count >= 3 else { return false }
        
        let lastChar = word.suffix(1)
        let secondLastChar = word.suffix(2).prefix(1)
        let thirdLastChar = word.suffix(3).prefix(1)
        
        // 最后一个字母是辅音
        guard !"aeiou".contains(lastChar.lowercased()) else { return false }
        
        // 倒数第二个字母是元音
        guard "aeiou".contains(secondLastChar.lowercased()) else { return false }
        
        // 倒数第三个字母是辅音
        guard !"aeiou".contains(thirdLastChar.lowercased()) else { return false }
        
        // 不以 w, x, y 结尾
        guard !"wxy".contains(lastChar.lowercased()) else { return false }
        
        return true
    }
}