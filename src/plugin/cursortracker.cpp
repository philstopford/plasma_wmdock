// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "cursortracker.h"
#include <QGuiApplication>
#include <QCursor>

CursorTracker::CursorTracker(QObject *parent)
    : QObject(parent)
{
    m_pos = QCursor::pos();
    connect(&m_timer, &QTimer::timeout, this, &CursorTracker::poll);
    m_timer.setInterval(50);   // poll at ~20 Hz
    m_timer.start();
}

void CursorTracker::poll()
{
    const QPoint p = QCursor::pos();
    if (p != m_pos) {
        m_pos = p;
        emit positionChanged();
    }
}
