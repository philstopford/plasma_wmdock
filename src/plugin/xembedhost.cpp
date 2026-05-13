// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#ifdef WITH_XEMBED

#include "xembedhost.h"

#include <QGuiApplication>
#include <QWindow>
#include <QProcess>
#include <QQuickWindow>
#include <QX11Info>
#include <xcb/xcb.h>

// XEMBED message IDs
static const uint32_t XEMBED_EMBEDDED_NOTIFY  = 0;
static const uint32_t XEMBED_FOCUS_IN         = 4;
static const uint32_t XEMBED_FOCUS_OUT        = 5;

// _XEMBED_INFO atom flags
static const uint32_t XEMBED_MAPPED = (1 << 0);

static xcb_atom_t atomXEmbed     = XCB_NONE;
static xcb_atom_t atomXEmbedInfo = XCB_NONE;

static xcb_atom_t internAtom(xcb_connection_t *conn, const char *name)
{
    xcb_intern_atom_cookie_t cookie = xcb_intern_atom(conn, 0, strlen(name), name);
    xcb_intern_atom_reply_t *reply  = xcb_intern_atom_reply(conn, cookie, nullptr);
    xcb_atom_t atom = reply ? reply->atom : XCB_NONE;
    free(reply);
    return atom;
}

XEmbedHost::XEmbedHost(QQuickItem *parent)
    : QQuickItem(parent)
    , m_conn(QX11Info::connection())
{
    atomXEmbed     = internAtom(m_conn, "_XEMBED");
    atomXEmbedInfo = internAtom(m_conn, "_XEMBED_INFO");

    createEmbedWindow();
}

XEmbedHost::~XEmbedHost()
{
    detach();
    destroyEmbedWindow();
}

void XEmbedHost::setCommand(const QString &cmd)
{
    if (cmd == m_command) return;
    m_command = cmd;
    Q_EMIT commandChanged();
}

void XEmbedHost::createEmbedWindow()
{
    if (!m_conn) return;

    const xcb_screen_t *screen = xcb_setup_roots_iterator(xcb_get_setup(m_conn)).data;
    if (!screen) return;

    const uint32_t mask   = XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK;
    const uint32_t values[2] = {
        screen->black_pixel,
        XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY | XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT
    };

    m_embedWin = xcb_generate_id(m_conn);
    xcb_create_window(m_conn, screen->root_depth, m_embedWin, screen->root,
                      0, 0, 64, 64, 0,
                      XCB_WINDOW_CLASS_INPUT_OUTPUT,
                      screen->root_visual, mask, values);
    xcb_map_window(m_conn, m_embedWin);
    xcb_flush(m_conn);
}

void XEmbedHost::destroyEmbedWindow()
{
    if (m_embedWin) {
        xcb_destroy_window(m_conn, m_embedWin);
        m_embedWin = 0;
        xcb_flush(m_conn);
    }
}

void XEmbedHost::launch()
{
    if (m_command.isEmpty() || !m_embedWin) return;

    // Pass the embed window ID to the dockapp via -w flag (standard convention)
    const QStringList args = {
        QStringLiteral("-w"),
        QString::number(m_embedWin)
    };

    auto *proc = new QProcess(this);
    proc->setProgram(m_command.section(QLatin1Char(' '), 0, 0));
    proc->setArguments(args + m_command.section(QLatin1Char(' '), 1).split(
                           QLatin1Char(' '), Qt::SkipEmptyParts));
    proc->start();
    m_pid = proc->processId();
}

void XEmbedHost::detach()
{
    if (m_clientWId) {
        xcb_unmap_window(m_conn, m_clientWId);
        xcb_reparent_window(m_conn,
                            m_clientWId,
                            xcb_setup_roots_iterator(xcb_get_setup(m_conn)).data->root,
                            0, 0);
        xcb_flush(m_conn);
        m_clientWId = 0;
        Q_EMIT clientChanged();
    }
}

bool XEmbedHost::event(QEvent *e)
{
    // Intercept native XCB events routed through Qt
    if (e->type() == QEvent::Type(QEvent::User + 1)) {
        auto *xcbEvent = reinterpret_cast<xcb_generic_event_t *>(
            static_cast<QChildEvent *>(e)->child());
        handleXcbEvent(xcbEvent);
    }
    return QQuickItem::event(e);
}

void XEmbedHost::handleXcbEvent(xcb_generic_event_t *event)
{
    if (!event) return;
    const uint8_t type = event->response_type & ~0x80;

    if (type == XCB_MAP_REQUEST) {
        auto *req = reinterpret_cast<xcb_map_request_event_t *>(event);
        // Reparent the dockapp window into our embed window
        xcb_reparent_window(m_conn, req->window, m_embedWin, 0, 0);
        xcb_map_window(m_conn, req->window);
        xcb_flush(m_conn);

        m_clientWId = req->window;
        Q_EMIT clientChanged();

        // Send XEMBED_EMBEDDED_NOTIFY
        xcb_client_message_event_t msg = {};
        msg.response_type  = XCB_CLIENT_MESSAGE;
        msg.format         = 32;
        msg.window         = m_clientWId;
        msg.type           = atomXEmbed;
        msg.data.data32[0] = XCB_CURRENT_TIME;
        msg.data.data32[1] = XEMBED_EMBEDDED_NOTIFY;
        msg.data.data32[2] = m_embedWin;
        xcb_send_event(m_conn, false, m_clientWId, XCB_EVENT_MASK_NO_EVENT,
                       reinterpret_cast<const char *>(&msg));
        xcb_flush(m_conn);
    }
}

#endif // WITH_XEMBED
