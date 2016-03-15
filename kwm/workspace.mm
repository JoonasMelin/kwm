#import "Cocoa/Cocoa.h"
#import "types.h"
#include "notifications.h"

extern void MoveCursorToCenterOfFocusedWindow();
extern void UpdateActiveSpace();
extern void UpdateActiveScreen();
extern bool FocusWindowOfOSX();
extern bool IsSpaceTransitionInProgress();
extern screen_info *GetDisplayOfWindow(window_info *Window);
extern void GiveFocusToScreen(int ScreenID, tree_node *Focus, bool Mouse);
extern space_info *GetActiveSpaceOfScreen(screen_info *Screen);

extern kwm_focus KWMFocus;
extern kwm_screen KWMScreen;
extern kwm_thread KWMThread;

@interface MDWorkspaceWatcher : NSObject {
}
- (id)init;
@end

@implementation MDWorkspaceWatcher
- (id)init
{
    if ((self = [super init]))
    {
       [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                selector:@selector(activeSpaceDidChange:)
                name:NSWorkspaceActiveSpaceDidChangeNotification
                object:nil];

       [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                selector:@selector(didActivateApplication:)
                name:NSWorkspaceDidActivateApplicationNotification
                object:nil];
    }

    return self;
}

- (void)dealloc
{
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    [super dealloc];
}

- (void)activeSpaceDidChange:(NSNotification *)notification
{
    UpdateActiveSpace();
}

- (void)didActivateApplication:(NSNotification *)notification
{
    pthread_mutex_lock(&KWMThread.Lock);

    pid_t ProcessID = [[notification.userInfo objectForKey:NSWorkspaceApplicationKey] processIdentifier];
    if(ProcessID != -1)
    {
        if((KWMFocus.Window && KWMFocus.Window->PID != ProcessID) ||
           !KWMFocus.Window)
        {
            if(FocusWindowOfOSX() && KWMFocus.Window)
            {
                screen_info *Screen = GetDisplayOfWindow(KWMFocus.Window);
                if(KWMScreen.Current != Screen)
                    GiveFocusToScreen(Screen->ID, NULL, false);
            }
        }
    }

    pthread_mutex_unlock(&KWMThread.Lock);
}

@end

void CreateWorkspaceWatcher(void *Watcher)
{
    MDWorkspaceWatcher *MDWatcher = [[MDWorkspaceWatcher alloc] init];
    Watcher = (void*)MDWatcher;
}

CFStringRef GetDisplayIdentifier(screen_info *Screen)
{
    if(Screen->Identifier)
        return Screen->Identifier;

    CGRect Frame = CGRectMake(Screen->X, Screen->Y, Screen->Width, Screen->Height);
    Screen->Identifier = CGSCopyBestManagedDisplayForRect(CGSDefaultConnection, Frame);
    return Screen->Identifier;
}

int GetActiveSpaceOfDisplay(screen_info *Screen)
{
    int CurrentSpace = -1;
    NSString *CurrentIdentifier = (__bridge NSString *)GetDisplayIdentifier(Screen);

    CFArrayRef ScreenDictionaries = CGSCopyManagedDisplaySpaces(CGSDefaultConnection);
    for(NSDictionary *ScreenDictionary in (__bridge NSArray *)ScreenDictionaries)
    {
        NSString *ScreenIdentifier = ScreenDictionary[@"Display Identifier"];
        if ([ScreenIdentifier isEqualToString:CurrentIdentifier])
        {
            CurrentSpace = [ScreenDictionary[@"Current Space"][@"id64"] intValue];
            break;
        }
    }

    CFRelease(ScreenDictionaries);
    return CurrentSpace;
}

int GetNumberOfSpacesOfDisplay(screen_info *Screen)
{
    int Result = 0;
    NSString *CurrentIdentifier = (__bridge NSString *)GetDisplayIdentifier(Screen);

    CFArrayRef ScreenDictionaries = CGSCopyManagedDisplaySpaces(CGSDefaultConnection);
    for(NSDictionary *ScreenDictionary in (__bridge NSArray *)ScreenDictionaries)
    {
        NSString *ScreenIdentifier = ScreenDictionary[@"Display Identifier"];
        if ([ScreenIdentifier isEqualToString:CurrentIdentifier])
        {
            NSArray *Spaces = ScreenDictionary[@"Spaces"];
            Result = CFArrayGetCount((__bridge CFArrayRef)Spaces);
        }
    }

    CFRelease(ScreenDictionaries);
    return Result;
}
