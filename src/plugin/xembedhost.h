// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#ifdef WITH_XEMBED

#include <QQuickItem>
#include <QWindow>
#include <xcb/xcb.h>

/**
 * @brief A QQuickItem that XEMBED-hosts a legacy WindowMaker dockapp.
 *
 * Creates an off-screen X11 window acting as the XEMBED container
 * and sets it as the child of the QQuickWindow's native handle.
 * Only available when compiled with WITH_XEMBED=1 on X11 sessions.
 */
class XEmbedHost : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(QString command   READ command   WRITE setCommand  NOTIFY commandChanged)
    Q_PROPERTY(quint32 clientWId READ clientWId NOTIFY clientChanged)
    Q_PROPERTY(bool    embedded  READ embedded  NOTIFY clientChanged)

public:
    explicit XEmbedHost(QQuickItem *parent = nullptr);
    ~XEmbedHost() override;

    QString command()   const { return m_command; }
    quint32 clientWId() const { return m_clientWId; }
    bool    embedded()  const { return m_clientWId != 0; }

    void setCommand(const QString &cmd);

    Q_INVOKABLE void launch();
    Q_INVOKABLE void detach();

Q_SIGNALS:
    void commandChanged();
    void clientChanged();

protected:
    bool event(QEvent *e) override;

private:
    void createEmbedWindow();
    void destroyEmbedWindow();
    void handleXcbEvent(xcb_generic_event_t *event);

    QString  m_command;
    xcb_connection_t *m_conn      = nullptr;
    xcb_window_t      m_embedWin  = 0;
    quint32           m_clientWId = 0;
    qint64            m_pid       = 0;
};

#endif // WITH_XEMBED
