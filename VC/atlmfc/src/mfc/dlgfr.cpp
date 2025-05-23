// This is a part of the Microsoft Foundation Classes C++ library.
// Copyright (C) Microsoft Corporation
// All rights reserved.
//
// This source code is only intended as a supplement to the
// Microsoft Foundation Classes Reference and related
// electronic documentation provided with the library.
// See these sources for detailed information regarding the
// Microsoft Foundation Classes product.

#include "stdafx.h"
#include <stddef.h>     // for offsetof macro



#define new DEBUG_NEW

/////////////////////////////////////////////////////////////////////////////
// Find/FindReplace dialogs

CFindReplaceDialog::CFindReplaceDialog() : CCommonDialog(NULL)
{
	memset(&m_fr, 0, sizeof(m_fr));
	m_szFindWhat[0] = '\0';
	m_szReplaceWith[0] = '\0';

	m_fr.Flags = FR_ENABLEHOOK;
	m_fr.lpfnHook = (COMMDLGPROC)_AfxCommDlgProc;
	m_fr.lStructSize = sizeof(m_fr);
	m_fr.lpstrFindWhat = (LPTSTR)m_szFindWhat;
}

void CFindReplaceDialog::PostNcDestroy()
{
	ASSERT(m_hWnd == NULL);
	delete this;
}

BOOL CFindReplaceDialog::Create(BOOL bFindDialogOnly,
	LPCTSTR lpszFindWhat, LPCTSTR lpszReplaceWith,
	DWORD dwFlags, CWnd* pParentWnd)
{
	ASSERT_VALID(this);
	ASSERT(m_fr.Flags & FR_ENABLEHOOK);
	ASSERT(m_fr.lpfnHook != NULL);

	m_nIDHelp = bFindDialogOnly ? AFX_IDD_FIND : AFX_IDD_REPLACE;

	m_fr.wFindWhatLen = _countof(m_szFindWhat);
	m_fr.lpstrReplaceWith = (LPTSTR)m_szReplaceWith;
	m_fr.wReplaceWithLen = _countof(m_szReplaceWith);
	m_fr.Flags |= dwFlags;

	if (pParentWnd == NULL)
		m_fr.hwndOwner = AfxGetMainWnd()->GetSafeHwnd();
	else
	{
		ASSERT_VALID(pParentWnd);
		m_fr.hwndOwner = pParentWnd->m_hWnd;
	}
	ASSERT(m_fr.hwndOwner != NULL); // must have a parent for modeless dialog

	if (lpszFindWhat != NULL)
		Checked::tcsncpy_s(m_szFindWhat, _countof(m_szFindWhat), lpszFindWhat, _TRUNCATE);

	if (lpszReplaceWith != NULL)
		Checked::tcsncpy_s(m_szReplaceWith, _countof(m_szReplaceWith), lpszReplaceWith, _TRUNCATE);

	HWND hWnd;

	AfxHookWindowCreate(this);
	if (bFindDialogOnly)
		hWnd = ::AfxCtxFindText(&m_fr);
	else
		hWnd = ::AfxCtxReplaceText(&m_fr);
	if (!AfxUnhookWindowCreate())
		PostNcDestroy();

	ASSERT(hWnd == NULL || hWnd == m_hWnd);
	return hWnd != NULL;
}

CFindReplaceDialog* PASCAL CFindReplaceDialog::GetNotifier(LPARAM lParam)
{
	ASSERT(lParam != NULL);
	CFindReplaceDialog* pDlg;

	pDlg = (CFindReplaceDialog*)(lParam - offsetof(CFindReplaceDialog, m_fr));
	ASSERT_VALID(pDlg);
	ASSERT_KINDOF(CFindReplaceDialog, pDlg);

	return pDlg;
}

////////////////////////////////////////////////////////////////////////////
// CFindReplaceDialog diagnostics

#ifdef _DEBUG
void CFindReplaceDialog::Dump(CDumpContext& dc) const
{
	CDialog::Dump(dc);

	dc << "m_fr.hwndOwner = " << m_fr.hwndOwner;
	dc << "\nm_fr.Flags = ";
	dc.DumpAsHex(m_fr.Flags);
	dc << "\nm_fr.lpstrFindWhat = " << m_fr.lpstrFindWhat;
	dc << "\nm_fr.lpstrReplaceWith = " << m_fr.lpstrReplaceWith;

	if (m_fr.lpfnHook == (COMMDLGPROC)_AfxCommDlgProc)
		dc << "\nhook function set to standard MFC hook function";
	else
		dc << "\nhook function set to non-standard hook function";

	dc << "\n";
}
#endif //_DEBUG


IMPLEMENT_DYNAMIC(CFindReplaceDialog, CCommonDialog)

////////////////////////////////////////////////////////////////////////////
