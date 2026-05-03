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

#define POLKIT_AGENT_I_KNOW_API_IS_SUBJECT_TO_CHANGE 1

#include <polkitagent/polkitagent.h>
#include <PolkitQt1/Subject>
#include <QVariant>

#include "policykitagent.h"
#include "policykitagentgui.h"

namespace LXQtPolicykit
{

PolicykitAgent::PolicykitAgent(QObject *parent)
    : PolkitQt1::Agent::Listener(parent),
      m_inProgress(false),
      m_inProgressAlert(false),
      m_gui(nullptr),
      m_infobox(nullptr)
{
    PolkitQt1::UnixSessionSubject session(getpid());
    registerListener(session, QStringLiteral("/org/lxqt/PolicyKit1/AuthenticationAgent"));
}

PolicykitAgent::~PolicykitAgent()
{
    if (m_gui != nullptr)
    {
        m_gui->blockSignals(true);
        m_gui->deleteLater();
    }
    delete m_infobox;
    deleteSessions();
}

void PolicykitAgent::deleteSessions()
{
    for (auto i = m_SessionIdentity.begin(), i_e = m_SessionIdentity.end(); i != i_e; ++i)
        delete i.key();
    m_SessionIdentity.clear();
}

void PolicykitAgent::initiateAuthentication(const QString &actionId,
                                            const QString &message,
                                            const QString &iconName,
                                            const PolkitQt1::Details &details,
                                            const QString &cookie,
                                            const PolkitQt1::Identity::List &identities,
                                            PolkitQt1::Agent::AsyncResult *result)
{
    if (m_inProgress)
    {
        const QString info = tr("Another authentication is in progress. Please try again later.");
        if (!m_inProgressAlert)
        {
            m_inProgressAlert = true;
            if (m_gui != nullptr)
            {
                m_gui->errorLabel->setStyleSheet(QStringLiteral("QLabel { color: #f3c98b; background: transparent; }"));
                m_gui->errorLabel->setText(info);
                m_gui->errorLabel->setVisible(true);
                m_gui->show();
                m_gui->activateWindow();
                m_gui->raise();
            }
            m_inProgressAlert = false;
        }
        result->setError(info);
        result->setCompleted();
        return;
    }
    m_inProgress = true;
    deleteSessions();

    if (m_gui != nullptr)
    {
        delete m_gui;
        m_gui = nullptr;
    }
    m_gui = new PolicykitAgentGUI(actionId, message, iconName, details, identities);
    if (m_gui != nullptr)
    {
        m_gui->errorLabel->setStyleSheet(QStringLiteral("QLabel { color: transparent; background: transparent; }"));
        m_gui->errorLabel->setText(QStringLiteral(" "));
        m_gui->errorLabel->setVisible(true);
        m_gui->descriptionLabel->setText(tr("An application is attempting to perform an action that requires privileges. Authentication is required to perform this action"));
    }

    for (const PolkitQt1::Identity &i : identities)
    {
        PolkitQt1::Agent::Session *session = new PolkitQt1::Agent::Session(i, cookie, result);
        Q_ASSERT(session);
        m_SessionIdentity[session] = i;
        connect(session, &PolkitQt1::Agent::Session::request, this, &PolicykitAgent::request);
        connect(session, &PolkitQt1::Agent::Session::completed, this, &PolicykitAgent::completed);
        connect(session, &PolkitQt1::Agent::Session::showError, this, &PolicykitAgent::showError);
        connect(session, &PolkitQt1::Agent::Session::showInfo, this, &PolicykitAgent::showInfo);
    }

    connect(m_gui, &QDialog::finished, this, [this, result] (int dialogResult)
    {
        if (!m_inProgress || m_gui == nullptr)
            return;

        if (dialogResult != QDialog::Accepted)
        {
            result->setCompleted();
            m_inProgress = false;
            m_gui->hide();
            deleteSessions();
            return;
        }

        const QString selectedIdentity = m_gui->identity();
        for (auto i = m_SessionIdentity.begin(), i_e = m_SessionIdentity.end(); i != i_e; ++i)
        {
            if (i.value().toString() == selectedIdentity)
            {
                i.key()->setProperty("ripperPendingResponse", m_gui->response());
                m_gui->hide();
                i.key()->initiate();
                return;
            }
        }

        result->setCompleted();
        m_inProgress = false;
        m_gui->hide();
        deleteSessions();
    });
    m_gui->show();
    m_gui->activateWindow();
    m_gui->raise();
}

bool PolicykitAgent::initiateAuthenticationFinish()
{
    // dunno what are those for...
    m_inProgress = false;
    return true;
}

void PolicykitAgent::cancelAuthentication()
{
    // dunno what are those for...
    m_inProgress = false;
}

void PolicykitAgent::request(const QString &request, bool echo)
{
    PolkitQt1::Agent::Session *session = qobject_cast<PolkitQt1::Agent::Session *>(sender());
    Q_ASSERT(session);
    Q_ASSERT(m_gui);

    PolkitQt1::Identity identity = m_SessionIdentity[session];
    if (identity.toString() != m_gui->identity())
        return;

    m_gui->setPrompt(identity, request, echo);
    const QVariant pendingResponse = session->property("ripperPendingResponse");
    if (pendingResponse.isValid())
    {
        session->setProperty("ripperPendingResponse", QVariant());
        session->setResponse(pendingResponse.toString());
        return;
    }

    disconnect(m_gui, &QDialog::finished, this, nullptr);
    connect(m_gui, &QDialog::finished, this, [this, session] (int result)
    {
        if (!m_inProgress || m_gui == nullptr || !m_SessionIdentity.contains(session))
            return;

        if (m_gui->identity() != m_SessionIdentity[session].toString())
            return;

        if (result == QDialog::Accepted)
            session->setResponse(m_gui->response());
        else
        {
            session->result()->setCompleted();
            m_inProgress = false;
            m_gui->hide();
            deleteSessions();
        }
    });
    m_gui->descriptionLabel->setText(tr("An application is attempting to perform an action that requires privileges. Authentication is required to perform this action"));
    m_gui->show();
    m_gui->activateWindow();
    m_gui->raise();
}

void PolicykitAgent::completed(bool gainedAuthorization)
{
    PolkitQt1::Agent::Session *session = qobject_cast<PolkitQt1::Agent::Session *>(sender());
    Q_ASSERT(session);
    Q_ASSERT(m_gui);

    if (m_inProgress && m_gui->identity() == m_SessionIdentity[session].toString())
    {
        if (!gainedAuthorization)
        {
            m_gui->errorLabel->setStyleSheet(QStringLiteral("QLabel { color: #ff9db2; background: transparent; }"));
            m_gui->errorLabel->setText(tr("Authorization failed for some reason"));
            m_gui->errorLabel->setVisible(true);
        }

        // Note: the setCompleted() must be called exacly once (as the
        // AsyncResult is shared by all the sessions)
        session->result()->setCompleted();
        m_inProgress = false;
        if (!gainedAuthorization)
            m_gui->hide();
    }
    if (m_infobox != nullptr){
      m_infobox->hide();
      delete m_infobox;
      m_infobox = nullptr;
    }
}

void PolicykitAgent::showError(const QString &text)
{
    if (m_gui != nullptr)
    {
        m_gui->errorLabel->setStyleSheet(QStringLiteral("QLabel { color: #ff9db2; background: transparent; }"));
        m_gui->errorLabel->setText(text);
        m_gui->errorLabel->setVisible(true);
        m_gui->show();
        m_gui->activateWindow();
        m_gui->raise();
    }
}

void PolicykitAgent::showInfo(const QString &text)
{
    if (m_gui != nullptr)
    {
        m_gui->errorLabel->setStyleSheet(QStringLiteral("QLabel { color: #f3c98b; background: transparent; }"));
        m_gui->errorLabel->setText(text);
        m_gui->errorLabel->setVisible(true);
        m_gui->show();
        m_gui->activateWindow();
        m_gui->raise();
    }
}

} // namespace
