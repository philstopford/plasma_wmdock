// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QObject>
#include <QTimer>
#include <QPoint>

/**
 * @brief Tracks the global mouse-cursor position.
 *
 * Polls QCursor::pos() every ~50 ms and emits positionChanged()
 * whenever the cursor moves.  Used by the WMEyes applet so the
 * pupils can follow the pointer even when it is outside the widget.
 *
 * Exposed to QML as a singleton via the wmdockplugin QML extension.
 */
class CursorTracker : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int cursorX READ cursorX NOTIFY positionChanged)
    Q_PROPERTY(int cursorY READ cursorY NOTIFY positionChanged)

public:
    explicit CursorTracker(QObject *parent = nullptr);

    int cursorX() const { return m_pos.x(); }
    int cursorY() const { return m_pos.y(); }

Q_SIGNALS:
    void positionChanged();

private Q_SLOTS:
    void poll();

private:
    QTimer m_timer;
    QPoint m_pos;
};
