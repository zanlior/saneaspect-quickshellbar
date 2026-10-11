pragma Singleton
import QtQuick
import "Defaults.js" as Defaults
import "ThemeData.js" as Themes
QtObject {
    property var settings: Defaults.values
    readonly property string clockFormat: settings.clock24 ? (settings.seconds ? 'HH:mm:ss' : 'HH:mm') : (settings.seconds ? 'h:mm:ss AP' : 'h:mm AP')
    readonly property string uiFont: settings.fontFamily || "Rubik"
    readonly property string monoFont: settings.monoFontFamily || "JetBrainsMono Nerd Font Mono"
    readonly property var palettes: {
        const result = {};
        for (const name of Object.keys(Themes.registry)) result[name] = Themes.registry[name].colors;
        return result;
    }
    readonly property var themeSamples: {
        const result = {};
        for (const name of Object.keys(Themes.registry)) result[name] = Themes.registry[name].samples;
        return result;
    }
    property var dynamicPalette: null
    readonly property var colors: (settings.theme === 'material-you' && dynamicPalette) || palettes[settings.theme] || palettes.ariadne
    readonly property color bg: colors[0]
    readonly property color panel: colors[1]
    readonly property color card: colors[2]
    readonly property color text: colors[3]
    readonly property color muted: colors[4]
    readonly property color accent: colors[5]
    readonly property int duration: settings.reduceMotion ? 0 : settings.movement
    readonly property int closeDuration: settings.reduceMotion ? 0 : Math.round(settings.movement * .72)
    readonly property var openCurve: [.05, .9, .1, 1 + settings.bounce * .00075, 1, 1]
    readonly property var closeCurve: [.4, 0, .2, 1, 1, 1]
    readonly property var settleCurve: [.25, 1, .5, 1, 1, 1]
}
