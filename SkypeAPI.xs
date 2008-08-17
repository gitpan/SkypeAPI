
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <skypeapi.h>
#include <windows.h>
#include <stdlib.h>    

static PerlInterpreter *ori_perl; //this one_perl interpriter is for the fucking multi-thread perl callback

HWND g_hWndSkype;       // window handle received in SkypeControlAPIAttach message
HWND g_hWndClient;      // our window handle
BOOL g_bNotAvailable;   // set by not-available msg from skype
BOOL is_verbose = TRUE;

static SV* callback_copydata;

// windows messages registered by skype
UINT SkypeControlAPIDiscover;
UINT SkypeControlAPIAttach;
enum {
SKYPECONTROLAPI_ATTACH_SUCCESS=0,
SKYPECONTROLAPI_ATTACH_PENDING_AUTHORIZATION,
SKYPECONTROLAPI_ATTACH_REFUSED,
SKYPECONTROLAPI_ATTACH_NOT_AVAILABLE,
SKYPECONTROLAPI_ATTACH_API_AVAILABLE= 0x8001,
};

// obtain the skype registered windows messages
BOOL SkypeRegisterMessages()
{
    SkypeControlAPIDiscover =RegisterWindowMessage("SkypeControlAPIDiscover");
    if (SkypeControlAPIDiscover==0) {
         if (is_verbose) printf("RegisterWindowMessage error\n");
        return FALSE;
    }
    if (is_verbose) printf("SkypeControlAPIDiscover=%04x\n", SkypeControlAPIDiscover);

    SkypeControlAPIAttach   =RegisterWindowMessage("SkypeControlAPIAttach");
    if (SkypeControlAPIAttach==0) {
        if (is_verbose) printf("RegisterWindowMessage error\n");
        return FALSE;
    }
        
    if (is_verbose) printf("SkypeControlAPIAttach=%04x\n", SkypeControlAPIAttach);
    return TRUE;
}


// handle skype api message, currently outputs the message to stdout.
void HandleSkypeMessage(HWND hWndSkype, COPYDATASTRUCT* cds)
{
    if (hWndSkype!=g_hWndSkype) {
        if (is_verbose) printf("msg: %08lx, global: %08lx\n", hWndSkype, g_hWndSkype);
    } else if (callback_copydata != NULL){ 
        PERL_SET_CONTEXT(ori_perl);
        {
            dSP;
            ENTER;
            SAVETMPS;              
            
            PUSHMARK(SP);
            XPUSHs(sv_2mortal(newSVpv((char*)cds->lpData, 0)));
            //XPUSHs(sv_2mortal(newSViv(hWndSkype)));
            PUTBACK;
            if (is_verbose) printf("callback_copydata %d\n", callback_copydata);
            call_sv(callback_copydata, G_DISCARD);
            FREETMPS;
            LEAVE;
        }
    }
    if (is_verbose) printf(">>%s\n", (char*)cds->lpData);   
    
}

// initiate connnection with skype.
BOOL  SkypeDiscover(HWND hWnd)
{
    LRESULT res;
    if (g_bNotAvailable)
        return FALSE;
    g_hWndSkype= NULL;

    res= SendMessage(HWND_BROADCAST, SkypeControlAPIDiscover, (WPARAM)hWnd, 0);
    if (is_verbose) printf("discover result=%08lx\n", res);
    return TRUE;
}

// process SkypeControlAPIAttach message
void HandleSkypeAttach(LPARAM lParam, WPARAM wParam)
{
    switch(lParam) {
    case SKYPECONTROLAPI_ATTACH_SUCCESS:
        g_hWndSkype= (HWND)wParam;
        if (is_verbose) printf("success: skypewnd= %08lx\n", g_hWndSkype);
        break;
    case SKYPECONTROLAPI_ATTACH_PENDING_AUTHORIZATION:
        if (is_verbose) printf("pending authorization\n");
        break;
    case SKYPECONTROLAPI_ATTACH_REFUSED:
        if (is_verbose) printf("attach refused\n");
        g_hWndSkype= NULL;
        break;
    case SKYPECONTROLAPI_ATTACH_NOT_AVAILABLE:
        if (is_verbose) printf("skype api not available\n");
        g_bNotAvailable= TRUE;
        break;
    case SKYPECONTROLAPI_ATTACH_API_AVAILABLE:
        if (is_verbose) printf("skype api available\n");
        g_bNotAvailable= FALSE;
        SkypeDiscover(g_hWndClient);
        break;
    default:
        if (is_verbose) printf("UNKNOWN SKYPEMSG %08lx: %08lx\n", lParam, wParam);
    }
}

// destroy our window.
void UnmakeWindow(HWND hWnd)
{
    if (!DestroyWindow(hWnd))
        if (is_verbose) printf("DestroyWindow\n");
    if (!UnregisterClass("itsme skype window", NULL))
        if (is_verbose) printf("UnregisterClass\n");
}

// our windowsproc
LRESULT CALLBACK SkypeWindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    if (uMsg==WM_CREATE) {
        if (!SkypeRegisterMessages()) {
            return -1;
        }
        
        if (!SkypeDiscover(hWnd)) {
            return -1;
        }    
        return 0;
    }
    else if (uMsg==WM_DESTROY) {
        return 0;
    }
    else if (uMsg==SkypeControlAPIAttach) {
        HandleSkypeAttach(lParam, wParam);        
        return 0;
    }
    else if (uMsg==SkypeControlAPIDiscover) {
        HWND hWndOther= (HWND)wParam;
        if (hWndOther!=hWnd)
            if (is_verbose) printf( "detected other skype api client: %08lx\n", hWndOther);
        return 0;
    }
    else if (uMsg==WM_COPYDATA) {
        HandleSkypeMessage((HWND)wParam, (COPYDATASTRUCT*)lParam);
        return TRUE;
    }
    else {
        if (is_verbose) printf( "wnd %08lx msg %08lx %08lx %08lx\n", hWnd, uMsg ,wParam, lParam);
        return DefWindowProc(hWnd, uMsg, wParam, lParam);
    }
}

HWND MakeWindow() {
	WNDCLASS wndcls;
    HWND hWnd;
    ATOM a;
    memset(&wndcls, 0, sizeof(WNDCLASS));   // start with NULL
	wndcls.lpfnWndProc = SkypeWindowProc;
	wndcls.lpszClassName = "itsme skype window";
	a = RegisterClass(&wndcls);
    if (a==0) {
        if (is_verbose) printf("register class failed\n");
        return 0;
    }
	hWnd= CreateWindowEx(0, wndcls.lpszClassName, "itsme skype window", 0, -1, -1, 0, 0, (HWND)NULL, (HMENU)NULL, (HINSTANCE)NULL, NULL);
	if (hWnd==NULL) {
        if (is_verbose) printf("create windowfailed\n");
        return 0;
    }
    return hWnd;
}
//
//void create_perl_interprter() {
//    dTHX;
//    PERL_SET_CONTEXT(one_perl);
//    one_perl = perl_alloc();
//    PERL_SET_CONTEXT(one_perl);
//    perl_construct(one_perl);
//}
//
//void destroy_perl_interprter() {
//    PERL_SET_CONTEXT(one_perl);
//    perl_free(one_perl);
//}

// window thread, creates window, and runs messageloop.
DWORD WINAPI SkypeWindowThread(LPVOID lpParameter)
{
    MSG msg;
    BOOL bRet;
       
    if (is_verbose) printf("SkypeWindowThread\n");
    g_hWndClient= MakeWindow();
    if (is_verbose) printf("starting messageloop clientwnd=%08lx\n", g_hWndClient);
   
    
    
    while ((bRet= GetMessage(&msg, NULL, 0, 0))!=0)
    { 
        if (bRet==-1 || msg.message == WM_QUIT)
            break;
        TranslateMessage(&msg); 
        DispatchMessage(&msg); 
    } 
    
    //destroy_perl_interprter();

    if (is_verbose) printf("end thread\n");
    return 0;
}

// creates window thread
BOOL MakeThread()
{    
    dTHX;
    HANDLE hThread;
    if (is_verbose) printf("making new perl\n");
    
    ori_perl = my_perl;
    //create_perl_interprter();

    hThread= CreateThread(NULL, 0, SkypeWindowThread, NULL, 0, NULL);
    if (is_verbose) printf("MakeThread\n");
    

    if (hThread==NULL || hThread==INVALID_HANDLE_VALUE) {
        if (is_verbose) printf("MakeThread error\n");
        return FALSE;
    }
    if (is_verbose) printf("MakeThread ok hThread=%08lx\n", hThread);
    return TRUE;
}

// sends skype api message to skype 
bool SkypeSendMessage(char *msg)
{
    COPYDATASTRUCT cds;
    cds.dwData= 0;
    cds.lpData= msg;
    cds.cbData= strlen(msg)+1;
    if (!SendMessage(g_hWndSkype, WM_COPYDATA, (WPARAM)g_hWndClient, (LPARAM)&cds)) {
        if (is_verbose) printf("skypesendmessage failed\n");
        SkypeDiscover(g_hWndClient);
        return FALSE;
    }
    return TRUE;
}



MODULE = SkypeAPI		PACKAGE = SkypeAPI		

void destroy()
    CODE:
    if (g_hWndClient != NULL) {
        UnmakeWindow(g_hWndClient);
        g_hWndClient= NULL;
    }


   
int
init(SV*  self, SV* option)     
    INIT:
    HV* hvoption;
    if (!SvROK(option) || SvTYPE(SvRV(option)) != SVt_PVHV) {           
        printf("option must be a hashref\n");
        XSRETURN_UNDEF;
    }
    hvoption = (HV *)SvRV(option);
    CODE:   
        if (hv_exists(hvoption, "is_verbose", 10)) {            
            SV** refval =  hv_fetch(hvoption,  "is_verbose",  10 , NULL);
            if (refval != NULL) {
                is_verbose = SvIV((SV*)(*refval));
                if (is_verbose) printf("get the copydata callback %d\n", callback_copydata);
            }
        }     
        if (hv_exists(hvoption, "copy_data", 9)) {            
            SV** refval =  hv_fetch(hvoption,  "copy_data",9, NULL);
            if (refval != NULL) {
                callback_copydata = (SV*)SvRV((*refval));
                if (is_verbose) printf("get the copydata callback %d\n", callback_copydata);
            }
        }       
        
        if (!MakeThread()) {
          XSRETURN_IV(0);
        }
        if (is_verbose) printf("ready\n");

    RETVAL = 1;
    OUTPUT:
    RETVAL
    
bool
send_message(SV*  self, char* msg)
    CODE:
    bool result = SkypeSendMessage(msg);
    RETVAL= result;
    OUTPUT:
    RETVAL        

