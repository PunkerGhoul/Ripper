{ pkgs, ... }:

let
  # Agente de polkit personalizado para X11 usando lxqt-policykit y overrideAttrs para aplicar el estilo QML
  lxqtPolicykitStyled = pkgs.lxqt.lxqt-policykit.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      cat > src/policykit-agent/main.qml <<'EOF'
      import QtQuick
      import QtQuick.Controls
      import QtQuick.Layouts

      ApplicationWindow {
        id: window

        property var windowWidth: Math.round(fontMetrics.height * 28.0)
        property var windowHeight: Math.round(fontMetrics.height * 13.0)
        property var heightSafeMargin: 18

        color: "#1f2432"
        title: "Authentication Required"

        minimumWidth: Math.max(windowWidth, mainLayout.Layout.minimumWidth) + mainLayout.anchors.margins * 2
        minimumHeight: Math.max(windowHeight, mainLayout.Layout.minimumHeight) + mainLayout.anchors.margins * 2 + heightSafeMargin
        maximumWidth: minimumWidth
        maximumHeight: minimumHeight
        visible: true
        onClosing: {
          hpa.setResult("fail");
        }

        FontMetrics {
          id: fontMetrics
        }

        Item {
          id: mainLayout

          anchors.fill: parent
          Keys.onEscapePressed: (e) => {
            hpa.setResult("fail");
          }
          Keys.onReturnPressed: (e) => {
            hpa.setResult("auth:" + passwordField.text);
          }
          Keys.onEnterPressed: (e) => {
            hpa.setResult("auth:" + passwordField.text);
          }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12

            Item {
              Layout.preferredHeight: Math.round(fontMetrics.height * 0.18)
            }

            Label {
              color: "#e9eeff"
              font.bold: true
              font.pointSize: Math.round(fontMetrics.height * 0.90)
              text: "Authenticating for " + hpa.getUser()
              Layout.alignment: Qt.AlignHCenter
              Layout.fillWidth: true
              Layout.maximumWidth: parent.width
              Layout.leftMargin: Math.round(fontMetrics.height * 0.6)
              Layout.rightMargin: Math.round(fontMetrics.height * 0.6)
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              wrapMode: Text.WordWrap
            }

            HSeparator {
              Layout.topMargin: Math.round(fontMetrics.height * 0.22)
              Layout.bottomMargin: Math.round(fontMetrics.height * 0.22)
            }

            Label {
              color: "#cfd7f3"
              text: hpa.getMessage()
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignHCenter
              Layout.maximumWidth: parent.width
              Layout.leftMargin: Math.round(fontMetrics.height * 0.6)
              Layout.rightMargin: Math.round(fontMetrics.height * 0.6)
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              wrapMode: Text.WordWrap
              font.pointSize: Math.round(fontMetrics.height * 0.56)
            }

            TextField {
              id: passwordField

              Layout.topMargin: Math.round(fontMetrics.height * 0.18)
              placeholderText: ""
              Layout.alignment: Qt.AlignLeft
              Layout.fillWidth: true
              Layout.leftMargin: fontMetrics.height * 1.2
              Layout.rightMargin: fontMetrics.height * 1.2
              horizontalAlignment: TextInput.AlignLeft
              leftPadding: 10
              rightPadding: 10
              hoverEnabled: true
              persistentSelection: true
              echoMode: TextInput.Password
              focus: true
              color: "#f1f5ff"
              selectionColor: "#9b74ff"
              selectedTextColor: "#ffffff"

              background: Rectangle {
                implicitWidth: Math.round(fontMetrics.height * 12.5)
                implicitHeight: Math.round(fontMetrics.height * 1.9)
                radius: 8
                color: "#2b3246"
                border.width: 1
                border.color: "#8f70df"
              }

              Text {
                text: "Password"
                visible: passwordField.text.length === 0
                color: "#b8bfd6"
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: passwordField.font.pixelSize
                font.family: passwordField.font.family
              }

              Connections {
                target: hpa
                function onFocusField() {
                  passwordField.focus = true;
                }
                function onBlockInput(block) {
                  passwordField.readOnly = block;
                  if (!block) {
                    passwordField.focus = true;
                    passwordField.selectAll();
                  }
                }
              }

            }

            Label {
              id: errorLabel

              visible: text.length > 0
              color: "#ff9db2"
              font.italic: true
              Layout.topMargin: Math.round(fontMetrics.height * 0.08)
              text: ""
              Layout.alignment: Qt.AlignHCenter
              Layout.fillWidth: true
              Layout.preferredHeight: visible ? implicitHeight : 0
              horizontalAlignment: Text.AlignHCenter

              Connections {
                target: hpa
                function onSetErrorString(e) {
                  errorLabel.text = e;
                }
              }

            }

            Item {
              Layout.preferredHeight: Math.round(fontMetrics.height * 0.02)
            }

            HSeparator {
              Layout.topMargin: Math.round(fontMetrics.height * 0.02)
              Layout.bottomMargin: Math.round(fontMetrics.height * 0.16)
            }

            Item {
              id: buttonBox
              Layout.fillWidth: true
              Layout.leftMargin: Math.round(fontMetrics.height * 0.6)
              Layout.rightMargin: Math.round(fontMetrics.height * 0.6)
              Layout.bottomMargin: Math.round(fontMetrics.height * 0.12)
              Layout.preferredHeight: Math.round(fontMetrics.height * 2.0)

              RowLayout {
                anchors.centerIn: parent
                spacing: Math.round(fontMetrics.height * 0.45)

                Button {
                  text: "Cancel"
                  background: Rectangle {
                    implicitWidth: Math.round(fontMetrics.height * 6.4)
                    implicitHeight: Math.round(fontMetrics.height * 1.9)
                    radius: 8
                    color: "#3a2f56"
                    border.width: 1
                    border.color: "#8f70df"
                  }
                  contentItem: Text {
                    text: parent.text
                    color: "#f2f5ff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pointSize: Math.round(fontMetrics.height * 0.56)
                  }
                  onClicked: (e) => {
                    hpa.setResult("fail");
                  }
                }

                Button {
                  text: "Authenticate"
                  background: Rectangle {
                    implicitWidth: Math.round(fontMetrics.height * 8.0)
                    implicitHeight: Math.round(fontMetrics.height * 1.9)
                    radius: 8
                    color: "#4a3a71"
                    border.width: 1
                    border.color: "#a884ff"
                  }
                  contentItem: Text {
                    text: parent.text
                    color: "#f2f5ff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pointSize: Math.round(fontMetrics.height * 0.56)
                  }
                  onClicked: (e) => {
                    hpa.setResult("auth:" + passwordField.text);
                  }
                }
              }
            }

          }

        }

        component Separator: Rectangle {
          color: "#7c5ec8"
        }

        component HSeparator: Separator {
          implicitHeight: 1
          Layout.fillWidth: true
          Layout.leftMargin: fontMetrics.height * 2
          Layout.rightMargin: fontMetrics.height * 2
        }

      }
      EOF
    '';
  });
in
{
  services.lxqt-policykit = {
    enable = true;
    package = lxqtPolicykitStyled;
  };
}
