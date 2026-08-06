// SPDX-License-Identifier: GPL-2.0-or-later
#include "drawerfileio.h"

#include <QFile>
#include <QSaveFile>

void DrawerFileIO::setError(const QString &error)
{
    if (m_lastError == error)
        return;
    m_lastError = error;
    Q_EMIT lastErrorChanged();
}

QString DrawerFileIO::read(const QUrl &url)
{
    const QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        setError(file.errorString());
        return {};
    }
    setError({});
    return QString::fromUtf8(file.readAll());
}

bool DrawerFileIO::write(const QUrl &url, const QString &contents)
{
    const QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)
        || file.write(contents.toUtf8()) < 0 || !file.commit()) {
        setError(file.errorString());
        return false;
    }
    setError({});
    return true;
}
