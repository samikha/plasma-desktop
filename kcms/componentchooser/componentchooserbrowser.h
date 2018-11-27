/***************************************************************************
                          componentchooserbrowser.h
                             -------------------
    copyright            : (C) 2002 by Joseph Wenninger
    email                : jowenn@kde.org
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License version 2 as     *
 *   published by the Free Software Foundationi                            *
 *                                                                         *
 ***************************************************************************/

#ifndef COMPONENTCHOOSERBROWSER_H
#define COMPONENTCHOOSERBROWSER_H

#include "ui_browserconfig_ui.h"
#include "componentchooser.h"

class CfgBrowser: public QWidget, public Ui::BrowserConfig_UI, public CfgPlugin
{
Q_OBJECT
public:
	CfgBrowser(QWidget *parent);
	virtual ~CfgBrowser();
	void load(KConfig *cfg) Q_DECL_OVERRIDE;
	void save(KConfig *cfg) Q_DECL_OVERRIDE;
	void defaults() Q_DECL_OVERRIDE;

protected Q_SLOTS:
	void selectBrowser();
	void configChanged();
	void selectBrowserApp();

Q_SIGNALS:
	void changed(bool);
private:
	QString m_browserExec;
	KService::Ptr m_browserService;
};

#endif /* COMPONENTCHOOSERBROWSER_H */

