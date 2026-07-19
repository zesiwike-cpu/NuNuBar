import Testing
@testable import AgentLightApp

@Test("the in-app language covers both settings languages")
func appLanguageProvidesChineseAndEnglishCopy() {
    #expect(AppLanguage.simplifiedChinese.nativeName == "简体中文")
    #expect(AppLanguage.english.nativeName == "English")
    #expect(AppLanguage.simplifiedChinese.text(.connect) == "接入")
    #expect(AppLanguage.english.text(.connect) == "Connect")
    #expect(AppLanguage.simplifiedChinese.text(.launchAtLogin) == "开机时自动启动")
    #expect(AppLanguage.english.text(.launchAtLogin) == "Launch at Login")
    #expect(SettingsSection.keyboard.title(in: .english) == "Keyboard")
    #expect(SettingsSection.lights.title(in: .simplifiedChinese) == "灯光")
    #expect(SettingsSection.about.title(in: .simplifiedChinese) == "关于")
    #expect(AppLanguage.simplifiedChinese.text(.statusDurations) == "状态显示时间")
    #expect(AppLanguage.english.text(.completionDuration) == "Complete")
}
