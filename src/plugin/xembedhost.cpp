// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#ifdef WITH_XEMBED

#include "xembedhost.h"

#include <QGuiApplication>
#include <QProcess>
#include <xcb/xcb.h>
#include <private/qtx11extras_p.h>    // QX11Info (Qt6 private)

// XEMBED client message sub-types
static const uint32_t XEMBED_EMBEDDED_NOTIFY = 0;

static xcb_atom_t s_atomXEmbed = XCB_NONE;

static xcb_atom_t internAtom(xcb_connection_t *conn, const char *name)
{
    xcb_intern_atom_cookie_t c = xcb_intern_atom(conn, 0, strlen(name), name);
    xcb_intern_atom_reply_t *r = xcb_intern_atom_reply(conn, c, nullptr);
    xcb_atom_t a = r ? r->atom : XCB_NONE;
    free(r);
    return a;
}

XEmbedHost::XEmbedHost(QQuickItem *parent)
    : QQuickItem(parent)
    , m_conn(QX11Info::connection())
{
    s_atomXEmbed = internAtom(m_conn, "_XEMBED");
    createEmbedWindow();

    // Register as a native event filter to receive XCB events
    qApp->installNativeEventFilter(this);
}

XEmbedHost::~XEmbedHost()
{
    qApp->removeNativeEventFilter(this);
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

    const uint32_t mask      = XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK;
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

    // Standard convention: pass embed window XID via -w flag
    const QStringList cmdParts = QProcess::splitCommand(m_command);
    if (cmdParts.isEmpty()) return;

    QStringList args = cmdParts.mid(1);
    args << QStringLiteral("-w") << QString::number(m_embedWin);

    auto *proc = new QProcess(this);
    connect(proc, &QProcess::errorOccurred, this, [proc](QProcess::ProcessError) {
        proc->deleteLater();
    });
    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            proc, &QProcess::deleteLater);
    proc->start(cmdParts.value(0), args);
}

void XEmbedHost::detach()
{
    if (!m_clientWId || !m_conn) return;

    xcb_unmap_window(m_conn, m_clientWId);
    xcb_reparent_window(m_conn,
                        m_clientWId,
                        xcb_setup_roots_iterator(xcb_get_setup(m_conn)).data->root,
                        0, 0);
    xcb_flush(m_conn);
    m_clientWId = 0;
    Q_EMIT clientChanged();
}

bool XEmbedHost::nativeEventFilter(const QByteArray &eventType,
                                    void             *message,
                                    qintptr          * /*result*/)
{
    if (eventType != "xcb_generic_event_t") return false;
    handleXcbEvent(static_cast<xcb_generic_event_t *>(message));
    return false;   // do not consume the event
}

void XEmbedHost::handleXcbEvent(xcb_generic_event_t *event)
{
    if (!event) return;
    const uint8_t type = event->response_type & ~0x80;

    if (type == XCB_MAP_REQUEST) {
        auto *req = reinterpret_cast<xcb_map_request_event_t *>(event);
        if (req->parent != m_embedWin) return;  // not our container

        xcb_reparent_window(m_conn, req->window, m_embedWin, 0, 0);
        xcb_map_window(m_conn, req->window);
        xcb_flush(m_conn);

        m_clientWId = req->window;
        Q_EMIT clientChanged();

        // Send XEMBED_EMBEDDED_NOTIFY to the client
        xcb_client_message_event_t msg{};
        msg.response_type  = XCB_CLIENT_MESSAGE;
        msg.format         = 32;
        msg.window         = m_clientWId;
        msg.type           = s_atomXEmbed;
        msg.data.data32[0] = XCB_CURRENT_TIME;
        msg.data.data32[1] = XEMBED_EMBEDDED_NOTIFY;
        msg.data.data32[2] = m_embedWin;
        xcb_send_event(m_conn, false, m_clientWId, XCB_EVENT_MASK_NO_EVENT,
                       reinterpret_cast<const char *>(&msg));
        xcb_flush(m_conn);
    }
}

#endif // WITH_XEMBED
