import QtQuick

// A cursor made in Plume, drawn from its SVG.
Image {
    id: root

    property string svg: ""

    source: root.svg !== "" ? "data:image/svg+xml;charset=utf-8," + encodeURIComponent(root.svg) : ""
    sourceSize.width: Math.max(16, Math.round(root.width * 2))
    sourceSize.height: Math.max(16, Math.round(root.height * 2))
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
    cache: false
    asynchronous: false
}
