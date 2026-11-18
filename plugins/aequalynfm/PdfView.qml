// a pdf's first page, rendered here. Its own file, loaded only when a pdf is shown: it
// needs QtQuick.Pdf (Arch: qt6-webengine), and without it only pdf previews are missing,
// not the whole file manager.
import QtQuick
import QtQuick.Pdf
import "root:/plugins/aequalynfm/compat"

Item {
    id: pv
    required property var prev

    PdfDocument {
        id: doc

        source: pv.prev.media
        onPageCountChanged: pv.prev.pages = doc.pageCount
    }

    Rectangle {
        anchors.centerIn: page
        width: page.paintedWidth
        height: page.paintedHeight
        color: "white"
        visible: page.status === Image.Ready
    }

    PdfPageImage {
        id: page

        anchors.fill: parent
        anchors.margins: Theme.dp(10)
        document: doc
        currentFrame: 0
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Math.ceil(width * 2)
    }
}
