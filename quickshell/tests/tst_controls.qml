import QtQuick
import QtTest
import ".."
import "../components"

Item {
    id: scene
    width: 900; height: 800
    QtObject {
        id: mock
        property var state: ({wifi:{enabled:true,networks:[]},audio:{outputs:[]},display:{brightness:25}})
        property var notifications: []
        function send() {}
        function clearNotifications() {}
        function dismiss() {}
    }
    ControlCenter {
        id: center
        x:20; y:20; width:520; height:contentHeight
        bridge:mock; editing:true
        onLayoutEdited:(order,sizes,heights)=>Style.settings=Object.assign({},Style.settings,{controlOrder:order,controlSizes:sizes,controlHeights:heights})
    }
    Level { id:level; x:570; y:20; width:250; value:25 }
    SignalSpy { id:moved; target:level; signalName:'moved' }
    TestCase {
        name:'IslandControls'
        when:windowShown
        property string defaults
        function initTestCase() { defaults=JSON.stringify(Style.settings) }
        function init() { Style.settings=JSON.parse(defaults);center.selected='';moved.clear();wait(40) }
        function test_resize_and_remove_keyboard() {
            let card=findChild(center,'card-wifi');verify(card!==null)
            mouseClick(card,50,20);compare(center.selected,'wifi')
            keyClick(Qt.Key_BracketRight)
            tryCompare(Style.settings.controlSizes,'wifi',4)
            keyClick(Qt.Key_Delete)
            verify(!Style.settings.controlOrder.includes('wifi'))
        }
        function test_drag_reorders_cards() {
            let card=findChild(center,'card-wifi');verify(card!==null)
            let p=card.mapToItem(scene,50,25)
            mousePress(card,50,25)
            mouseMove(scene,p.x+20,p.y,30)
            mouseMove(scene,p.x+228,p.y,30)
            mouseRelease(scene,p.x+228,p.y)
            tryCompare(Style.settings.controlOrder,0,'focus')
            compare(Style.settings.controlOrder[1],'wifi')
        }
        function test_resize_corner() {
            let card=findChild(center,'card-wifi');mouseClick(card,50,20)
            let handle=findChild(center,'resize-wifi');verify(handle!==null)
            let p=handle.mapToItem(scene,12,12)
            mousePress(handle,12,12)
            mouseMove(scene,p.x+74,p.y,30)
            mouseRelease(scene,p.x+74,p.y)
            compare(Style.settings.controlSizes.wifi,4)
        }
        function test_slider_updates_before_backend_poll() {
            mousePress(level,200,14)
            verify(level.shownValue>70)
            compare(level.value,25)
            mouseRelease(level,200,14)
            verify(moved.count>=1)
            compare(Math.round(moved.signalArguments[moved.count-1][0]),80)
        }
        function test_control_rows_stay_together_while_width_changes() {
            const originalWidth = center.width;
            const originalHeight = center.contentHeight;
            const wifi = findChild(center, 'card-wifi');
            const lock = findChild(center, 'card-lock');
            try {
                for (const width of [467, 487, 507, 517, 518, 519, 520]) {
                    center.width = width;
                    wait(40);
                    compare(lock.y, wifi.y);
                    compare(center.contentHeight, originalHeight);
                }
            } finally {
                center.width = originalWidth;
                wait(40);
            }
        }
    }
}
