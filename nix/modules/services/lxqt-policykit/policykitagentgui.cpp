/* BEGIN_COMMON_COPYRIGHT_HEADER
 * (c)LGPL2+
 *
 * LXQt - a lightweight, Qt based, desktop toolset
 * https://lxqt.org
 *
 * Copyright: 2011-2012 Razor team
 * Authors:
 *   Petr Vanek <petr@scribus.info>
 *
 * This program or library is free software; you can redistribute it
 * and/or modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General
 * Public License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 *
 * END_COMMON_COPYRIGHT_HEADER */

#include <QIcon>
#include <QPainter>
#include <QPixmap>
#include "policykitagentgui.h"
#include <unistd.h>

namespace
{
QPixmap createKeyPixmap(int size)
{
    QPixmap pixmap(size, size);
    pixmap.fill(Qt::transparent);

    QPainter painter(&pixmap);
    painter.setRenderHint(QPainter::Antialiasing, true);
    painter.setPen(Qt::NoPen);
    painter.setBrush(QColor("#a884ff"));

    const int headRadius = size / 5;
    const int headX = size / 5;
    const int headY = size / 4;
    painter.drawEllipse(QRect(headX, headY, headRadius * 2, headRadius * 2));

    const int shaftX = headX + headRadius * 2 - 1;
    const int shaftY = headY + headRadius - 2;
    const int shaftHeight = headRadius;
    painter.drawRoundedRect(QRect(shaftX, shaftY, size - shaftX - size / 8, shaftHeight), 2, 2);

    painter.drawRect(QRect(size - size / 4, shaftY, size / 12, shaftHeight + size / 12));
    painter.drawRect(QRect(size - size / 6, shaftY, size / 12, shaftHeight + size / 16));

    return pixmap;
}
} // namespace

namespace LXQtPolicykit
{

PolicykitAgentGUI::PolicykitAgentGUI(const QString &actionId,
                                     const QString &message,
                                     const QString &iconName,
                                     const PolkitQt1::Details &details,
                                     const PolkitQt1::Identity::List &identities)
   : QDialog(nullptr, Qt::WindowStaysOnTopHint)
{
    setupUi(this);
    setWindowTitle(tr("Authentication Required"));
    Q_UNUSED(actionId);
    Q_UNUSED(details); // it seems too confusing for end user (=me)
    setStyleSheet(QStringLiteral(
        "QDialog { background-color: #1f2432; }"
        "QLabel { color: #e9eeff; }"
        "QLineEdit { background-color: #2b3246; color: #f1f5ff;"
        " border: 1px solid #8f70df; border-radius: 8px; padding: 6px; }"
        "QPushButton { background-color: #3a2f56; color: #f2f5ff;"
        " border: 1px solid #8f70df; border-radius: 8px; padding: 6px; }"
        "QPushButton:hover { background-color: #4a3a71; }"
        "QPushButton:pressed { background-color: #2a1f46; }"
    ));

    messageLabel->setText(message);
    QIcon icon = QIcon::fromTheme(QStringLiteral("dialog-password"));
    if (icon.isNull())
        icon = QIcon::fromTheme(iconName.isEmpty() ? QStringLiteral("dialog-question") : iconName);
    if (icon.isNull())
        icon = QIcon::fromTheme(QStringLiteral("dialog-question"));
    QPixmap iconPixmap = icon.pixmap(48, 48);
    if (iconPixmap.isNull())
        iconPixmap = createKeyPixmap(48);
    iconLabel->setPixmap(iconPixmap);

    errorLabel->clear();
    errorLabel->setVisible(false);

    const uid_t current_uid = getuid();
    QString selected_identity;
    for (const PolkitQt1::Identity& identity : identities)
    {
        PolkitQt1::UnixUserIdentity const * const u_id = static_cast<const PolkitQt1::UnixUserIdentity *>(&identity);
        if (u_id != nullptr && u_id->uid() == current_uid)
        {
            selected_identity = identity.toString();
            break;
        }
        if (selected_identity.isEmpty())
            selected_identity = identity.toString();
    }
    setProperty("ripperIdentity", selected_identity);
    promptLabel->setText(QCoreApplication::translate("PolicykitAgentGUI", "Password:"));
    passwordEdit->setFocus(Qt::OtherFocusReason);
}

PolicykitAgentGUI::~PolicykitAgentGUI() = default;

void PolicykitAgentGUI::setPromptLabel(const QString &text)
{
    if (QString::compare(text.trimmed(), QLatin1StringView("Password:"), Qt::CaseInsensitive) == 0)
        promptLabel->setText(QCoreApplication::translate("PolicykitAgentGUI", "Password:"));
    else
        promptLabel->setText(text);
}

void PolicykitAgentGUI::setPrompt(const PolkitQt1::Identity &identity, const QString &text, bool echo)
{
    Q_UNUSED(identity);
    errorLabel->clear();
    errorLabel->setVisible(false);
    setPromptLabel(text);
    passwordEdit->setEchoMode(echo ? QLineEdit::Normal : QLineEdit::Password);
}

QString PolicykitAgentGUI::identity()
{
    const QString selected = property("ripperIdentity").toString();
    Q_ASSERT(!selected.isEmpty());
    return selected;
}

QString PolicykitAgentGUI::response() {
  QString response = passwordEdit->text();
  passwordEdit->setText(QString());
  return response;
}

void PolicykitAgentGUI::onIdentityChanged(int index)
{
    Q_UNUSED(index);
}

} // namespace
