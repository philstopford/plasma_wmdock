// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QUrl>

class DrawerFileIO : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit DrawerFileIO(QObject *parent = nullptr) : QObject(parent) {}

    QString lastError() const { return m_lastError; }
    Q_INVOKABLE QString read(const QUrl &url);
    Q_INVOKABLE bool write(const QUrl &url, const QString &contents);

Q_SIGNALS:
    void lastErrorChanged();

private:
    void setError(const QString &error);
    QString m_lastError;
};
