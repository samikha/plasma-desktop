/*
 * Copyright (C) 2007 Matthew Woehlke <mw_triad@users.sourceforge.net>
 * Copyright (C) 2007 Jeremy Whiting <jpwhiting@kde.org>
 * Copyright (C) 2016 Olivier Churlaud <olivier@churlaud.com>
 * Copyright (C) 2019 Kai Uwe Broulik <kde@privat.broulik.de>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License or (at your option) version 3 or any later version
 * accepted by the membership of KDE e.V. (or its successor approved
 * by the membership of KDE e.V.), which shall act as a proxy
 * defined in Section 14 of version 3 of the license.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "sourcesmodel.h"

#include <QCollator>
#include <QDir>
#include <QStandardPaths>
#include <QStringList>
#include <QRegularExpression>

#include <KConfig>
#include <KConfigGroup>
#include <KSharedConfig>
#include <KService>
#include <KServiceTypeTrader>

#include <algorithm>

#include <QDebug>

SourcesModel::SourcesModel(QObject *parent) : QAbstractItemModel(parent)
{

}

SourcesModel::~SourcesModel() = default;

QPersistentModelIndex SourcesModel::makePersistentModelIndex(int row) const
{
    return QPersistentModelIndex(index(row, 0));
}

int SourcesModel::columnCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return 1;
}

int SourcesModel::rowCount(const QModelIndex &parent) const
{
    if (parent.column() > 0) {
        return 0;
    }

    if (!parent.isValid()) {
        return m_data.count();
    }

    if (parent.internalId()) {
        return 0;
    }

    return m_data.at(parent.row()).events.count();
}

QVariant SourcesModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid()) {
        return QVariant();
    }

    if (index.internalId()) {
        const auto &event = m_data.at(index.internalId() - 1).events.at(index.row());

        switch (role) {
        case Qt::DisplayRole: return event.name;
        case Qt::DecorationRole: return event.iconName;
        case EventIdRole: return event.eventId;
        case ActionsRole: return event.actions;
        }

        return QVariant();
    }

    const auto &source = m_data.at(index.row());

    switch (role) {
    case Qt::DisplayRole: return source.display();
    case Qt::DecorationRole: return source.iconName;
    case SourceTypeRole:
        if (!source.notifyRcName.isEmpty()) {
            if (!source.desktopEntry.isEmpty()) {
                return KNotifyAppType;
            }
            return ServiceType;
        }
        return FdoAppType;
    case NotifyRcNameRole: return source.notifyRcName;
    case DesktopEntryRole: return source.desktopEntry;
    }

    return QVariant();
}

bool SourcesModel::setData(const QModelIndex &index, const QVariant &value, int role)
{
    if (!index.isValid()) {
        return false;
    }

    if (!index.internalId()) {
        return false;
    }

    bool dirty = false;

    auto &event = m_data[index.internalId() - 1].events[index.row()];
    switch (role) {
    case ActionsRole:
        event.actions = value.toStringList();
        dirty = true;
        break;
    }

    if (dirty) {
        emit dataChanged(index, index, {role});
    }

    return dirty;
}

QModelIndex SourcesModel::index(int row, int column, const QModelIndex &parent) const
{
    if (row < 0 || column != 0) {
        return QModelIndex();
    }

    if (parent.isValid()) {
        const auto events = m_data.at(parent.row()).events;
        if (row < events.count()) {
            return createIndex(row, column, parent.row() + 1);
        }

        return QModelIndex();
    }

    if (row < m_data.count()) {
        return createIndex(row, column, nullptr);
    }

    return QModelIndex();
}

QModelIndex SourcesModel::parent(const QModelIndex &child) const
{
    if (child.internalId()) {
        return createIndex(child.internalId() - 1, 0, nullptr);
    }

    return QModelIndex();
}

QHash<int, QByteArray> SourcesModel::roleNames() const
{
    return {
        {Qt::DisplayRole, QByteArrayLiteral("display")},
        {Qt::DecorationRole, QByteArrayLiteral("decoration")},
        {SourceTypeRole, QByteArrayLiteral("sourceType")},
        {NotifyRcNameRole, QByteArrayLiteral("notifyRcName")},
        {DesktopEntryRole, QByteArrayLiteral("desktopEntry")},
        {EventIdRole, QByteArrayLiteral("eventId")},
        {ActionsRole, QByteArrayLiteral("actions")}
    };
}

void SourcesModel::load()
{
    beginResetModel();

    m_data.clear();

    QVector<SourceData> servicesData;
    QVector<SourceData> knotifyAppsData;
    QVector<SourceData> fdoAppsData;

    QStringList notifyRcFiles;
    QStringList desktopEntries;

    const QStringList dirs = QStandardPaths::locateAll(QStandardPaths::GenericDataLocation,
                            QStringLiteral("knotifications5"), QStandardPaths::LocateDirectory);

    for (const QString &dir : dirs) {
        const QStringList fileNames = QDir(dir).entryList(QStringList() << QStringLiteral("*.notifyrc"));
        for (const QString &file : fileNames) {
            if (notifyRcFiles.contains(file)) {
                continue;
            }

            notifyRcFiles.append(file);

            //const QString path = dir + QLatin1Char('/') + file;

            //KConfig config(path, KConfig::NoGlobals, QStandardPaths::DataLocation);

            KConfig *config = new KConfig(file, KConfig::NoGlobals);
            config->addConfigSources(QStandardPaths::locateAll(QStandardPaths::GenericDataLocation,
                                        QStringLiteral("knotifications5/") + file));

            KConfigGroup globalGroup(config, QLatin1String("Global"));

            const QRegularExpression regExp(QStringLiteral("^Event/([^/]*)$"));
            const QStringList groups = config->groupList().filter(regExp);

            const QString notifyRcName = file.section(QLatin1Char('.'), 0, -2);
            const QString desktopEntry = globalGroup.readEntry(QStringLiteral("DesktopEntry"));
            if (!desktopEntry.isEmpty()) {
                desktopEntries.append(desktopEntry);
            }

            SourceData source{
                // The old KCM read the Name and Comment from global settings disregarding
                // any user settings and just used user-specific files for actions config
                // I'm pretty sure there's a readEntry equivalent that does that without
                // reading the config stuff twice, assuming we care about this to begin with
                globalGroup.readEntry(QStringLiteral("Name")),
                globalGroup.readEntry(QStringLiteral("Comment")),
                globalGroup.readEntry(QStringLiteral("IconName")),
                notifyRcName,
                desktopEntry,
                {}, // events
                config
            };

            QVector<EventData> events;
            for (const QString &group : groups) {
                KConfigGroup cg(config, group);

                const QString eventId = regExp.match(group).captured(1);
                // TODO context stuff

                // TODO load defaults thing

                EventData event{
                    cg.readEntry("Name"),
                    cg.readEntry("Comment"),
                    cg.readEntry("IconName"),
                    eventId,
                    // TODO Flags?
                    cg.readEntry("Action").split(QLatin1Char('|'))
                };
                events.append(event);
            }

            source.events = events;

            if (!source.desktopEntry.isEmpty()) {
                knotifyAppsData.append(source);
            } else {
                servicesData.append(source);
            }
        }
    }

    const auto services = KServiceTypeTrader::self()->query(QStringLiteral("Application"),
                                                            QStringLiteral("exist Exec and TRUE == [X-GNOME-UsesNotifications]"));
    for (const auto &service : services) {
        if (desktopEntries.contains(service->desktopEntryName())) {
            continue;
        }

        SourceData source{
            service->name(),
            service->comment(),
            service->icon(),
            QString(), //notifyRcFile
            service->desktopEntryName(),
            {},
            nullptr
        };
        fdoAppsData.append(source);
    }

    QCollator collator;

    auto sortData = [&collator](const SourceData &a, const SourceData &b) {
        return collator.compare(a.display(), b.display()) < 0;
    };

    std::sort(servicesData.begin(), servicesData.end(), sortData);
    std::sort(knotifyAppsData.begin(), knotifyAppsData.end(), sortData);
    std::sort(fdoAppsData.begin(), fdoAppsData.end(), sortData);

    m_data << servicesData << knotifyAppsData << fdoAppsData;

    endResetModel();
}
