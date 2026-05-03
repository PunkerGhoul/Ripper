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
#include <QFont>
#include "policykitagentgui.h"
#include <unistd.h>

namespace
{
QPixmap createLockPixmap(int size)
{
    QPixmap pixmap(size, size);
    pixmap.fill(Qt::transparent);

    QPainter painter(&pixmap);
    painter.setRenderHint(QPainter::Antialiasing, true);
    painter.setPen(QPen(QColor("#c7b2ff"), 2));

    const int bodyW = (size * 34) / 56;
    const int bodyH = (size * 24) / 56;
    const int bodyX = (size - bodyW) / 2;
    const int bodyY = (size * 26) / 56;
    const QRect bodyRect(bodyX, bodyY, bodyW, bodyH);

    painter.setBrush(QColor("#a884ff"));
    painter.drawRoundedRect(bodyRect, 6, 6);

    const int shackleW = (size * 20) / 56;
    const int shackleH = (size * 20) / 56;
    const int shackleX = (size - shackleW) / 2;
    const int shackleY = (size * 7) / 56;
    const QRect shackleOuter(shackleX, shackleY, shackleW, shackleH);

    painter.setBrush(QColor("#c7b2ff"));
    painter.drawRoundedRect(shackleOuter, shackleW / 2, shackleW / 2);

    const int inset = qMax(2, size / 14);
    const QRect shackleInner(shackleX + inset, shackleY + inset, shackleW - inset * 2, shackleH - inset);
    painter.setPen(Qt::NoPen);
    painter.setBrush(QColor("#1f2432"));
    painter.drawRoundedRect(shackleInner, qMax(2, shackleW / 3), qMax(2, shackleW / 3));

    painter.setPen(Qt::NoPen);
    painter.setBrush(QColor("#1f2432"));
    const int keyholeW = qMax(2, size / 12);
    const int keyholeH = qMax(5, size / 7);
    const int keyholeX = bodyRect.center().x() - (keyholeW / 2);
    const int keyholeY = bodyRect.center().y() - (keyholeH / 2);
    painter.drawEllipse(QRect(keyholeX, keyholeY - keyholeW / 2, keyholeW, keyholeW));
    painter.drawRoundedRect(QRect(keyholeX, keyholeY, keyholeW, keyholeH), 2, 2);

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
        "QPushButton#cancelButton { background-color: rgba(31, 36, 50, 0.82); color: #cfd7f3; }"
        "QPushButton#cancelButton:hover { background-color: #4a3a71; color: #f2f5ff; }"
        "QPushButton#cancelButton:pressed { background-color: #2a1f46; color: #f2f5ff; }"
        "QPushButton:hover { background-color: #4a3a71; }"
        "QPushButton:pressed { background-color: #2a1f46; }"
    ));

    messageLabel->setText(message);
    QFont titleFont = messageLabel->font();
    titleFont.setBold(true);
    titleFont.setPointSize(titleFont.pointSize() + 1);
    messageLabel->setFont(titleFont);
    descriptionLabel->setFont(QFont(descriptionLabel->font().family(), descriptionLabel->font().pointSize()));
    errorLabel->setFont(QFont(errorLabel->font().family(), errorLabel->font().pointSize()));
    QIcon icon = QIcon::fromTheme(QStringLiteral("security-high"));
    if (icon.isNull())
        icon = QIcon::fromTheme(QStringLiteral("dialog-password"));
    if (icon.isNull())
        icon = QIcon::fromTheme(iconName.isEmpty() ? QStringLiteral("dialog-question") : iconName);
    if (icon.isNull())
        icon = QIcon::fromTheme(QStringLiteral("dialog-question"));
    QPixmap iconPixmap = icon.pixmap(56, 56);
    if (iconPixmap.isNull())
        iconPixmap = createLockPixmap(56);
    iconLabel->setPixmap(iconPixmap);

    messageLabel->setWordWrap(true);
    descriptionLabel->setWordWrap(true);
    descriptionLabel->setText(tr("An application is attempting to perform an action that requires privileges. Authentication is required to perform this action"));
    errorLabel->setStyleSheet(QStringLiteral("QLabel { color: #ff9db2; background: transparent; }"));
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
