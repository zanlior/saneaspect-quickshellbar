import QtQuick
import Quickshell
import "."
ShellRoot {
    id:test
    property var applications: DesktopEntries.applications.values
    function iconPath(name) { return Quickshell.iconPath(name, true); }
    property var state: ({media:{title:'Sample Track',artist:'Example Artist',album:'Example Album',player:'Spotify',art:Qt.resolvedUrl('tests/fixtures/cover.svg'),length:178,position:126,playing:false},wifi:{enabled:true,networks:[{ssid:'Example Wi-Fi',active:true,signal:63,security:'WPA2',device:'wlan0'}]},bluetooth:{enabled:true,devices:[{name:'Headphones',address:'AA:BB:CC:DD:EE:FF',paired:true,connected:false}]},audio:{outputs:[{id:'1',name:'speakers',label:'Built-in Audio Analog Stereo',volume:40}],inputs:[{id:'2',name:'mic',label:'Microphone',volume:80}],apps:[{id:'3',label:'Spotify',volume:100}],defaultOutput:'speakers',defaultInput:'mic'},display:{brightness:40,monitors:[{name:'DP-1',make:'ASUSTek COMPUTER INC',model:'VG248',width:1920,height:1080,refreshRate:164.917,scale:1,focused:true,brightness:40,brightnessKind:'ddc',availableModes:['1920x1080@164.92Hz','1920x1080@144Hz','1920x1080@60Hz']}]},wallpapers:[],capabilities:{nmcli:true,pactl:true}})
    property var notifications:[{appName:'notify-send',summary:'hello',body:'hi',actions:[]}]
    property var toast:null
    property string error:''
    function send(a,v,e) { console.log('PREVIEW ACTION',a,JSON.stringify(v)) }
    function clearNotifications() {notifications=[]}
    function dismiss(n) {}
    property var pages:['','glance','calendar','media','control','wifi','bluetooth','sound','display','launcher','power','themes','wallpapers','settings','settings-control','settings-motion','settings-launcher','settings-notifications','settings-appearance','settings-system','settings-lock','game']
    property int stage:0
    FloatingWindow {
        id:win
        visible:true;implicitWidth:1440;implicitHeight:900;color:'#087e71'
        Item {
            id:canvas;anchors.fill:parent
            Rectangle { anchors.fill:parent;color:"#087e71" }
            Island{id:island;anchors.fill:parent;bridge:test;visible:test.stage<13||test.stage===21}
            Settings{id:settings;anchors.fill:parent;anchors.margins:40;bridge:test;visible:test.stage>=13&&test.stage!==21;Rectangle{anchors.fill:parent;z:-1;color:Style.bg;radius:24}}
        }
    }
    Timer { interval:900;running:true;repeat:true;onTriggered: {canvas.grabToImage(r=>{r.saveToFile('/tmp/island-preview-'+(test.pages[test.stage]||'collapsed')+'.png');test.stage++;if(test.stage>=test.pages.length){Qt.quit()}else {island.page=test.stage<13?test.pages[test.stage]:'';settings.section=({14:'Control Center',15:'Motion',16:'Launcher',17:'Notifications',18:'Appearance',19:'System',20:'Lock Screen'})[test.stage]||'Bar & Island';if(test.stage===21)Style.settings=Object.assign({},Style.settings,{gameMode:true})}})} }
}
