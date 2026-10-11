import QtQuick
import ".."

Canvas {
    implicitWidth: 33
    implicitHeight: 33
    property color ink: Style.text
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext('2d');
        c.reset();
        c.scale(width / 33, height / 33);
        c.lineCap = 'round';
        c.strokeStyle = ink;
        c.lineWidth = 1.9;
        // The lower segment stays dim, as in the reference status disc.
        c.globalAlpha = .28;
        c.beginPath(); c.arc(16.5, 16.5, 12.4, 0, Math.PI * 2); c.stroke();
        c.globalAlpha = 1;
        c.beginPath(); c.arc(16.5, 16.5, 12.4, Math.PI * .72, Math.PI * 2.35); c.stroke();
        c.lineWidth = 1.65;
        for (const radius of [6.3, 3.65]) {
            c.beginPath(); c.arc(16.5, 20, radius, Math.PI * 1.23, Math.PI * 1.77); c.stroke();
        }
        c.fillStyle = ink;
        c.beginPath(); c.arc(16.5, 20, 1.05, 0, Math.PI * 2); c.fill();
    }
}
