//
//  metalbiew.mm
//  DR DEV Menu - PUBG Mobile
//

#import "ESP/metalbiew.h"
#import "ESP/mahoa.h"
#include "sys/mman.h"
#include "ESP/Tools.h"
#import <AVFoundation/AVFoundation.h>
#include <stdio.h>
#include <stdint.h>
#include <string>
#include <vector>
#include <map>
#include <dlfcn.h>
#include <unistd.h>
#include <stdlib.h>
#include "ESP/Icon.h"
#include "ESP/XORstringV2.h"
#include "ESP/Vector3.hpp"
#include "ESP/Vector2.hpp"
#import <Foundation/Foundation.h>
#import "ESP/UE4.h"
#import "ESP/PubgLoad.h"
#include "ESP/imgui/imgui.h"
#include "ESP/imgui_notify.h"
#import "ESP/HeeeNoScreenShotView.h"
#import "ESP/font.h"
#import "ESP/ini_rw.h"

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height

// ==================== ئۆفسێتەکان (بەپێی نسخە) ====================
#define OFFSET_GWORLD_GL       0x10A5D9D50
#define OFFSET_GWORLD_KR       0x10A6913D0
#define OFFSET_GWORLD_TW       0x10A66C350
#define OFFSET_GWORLD_VNG      0x109E33F50
#define OFFSET_GWORLD_BGMI     0x1095B72D0

#define OFFSET_GNAMES_GL       0x104D53FD4
#define OFFSET_GNAMES_KR       0x104E2D1C0
#define OFFSET_GNAMES_TW       0x104E02D90
#define OFFSET_GNAMES_VNG      0x104A35D60
#define OFFSET_GNAMES_BGMI     0x10426CD48

#define PROCESS_EVENT_INDEX    76
#define SHOOT_EVENT_INDEX      174
#define BROADCAST_INDEX        1002

// ==================== پێکهاتەکان ====================
struct JsonPreferences {
    int xsuit = 0; int bag = 0; int helmet = 0;
    bool Outfit = false; bool Bagg = false; bool Helmett = false;
    bool M416 = false; bool AKM = false; bool SCARL = false;
    bool M762 = false; bool AWM = false;
};
JsonPreferences preferences;

struct snew_Skin {
    int XSuits = 403003; int AKM = 101001; int M416_1 = 101004;
    int Scar = 101003; int M762 = 101008; int AWM = 103003;
};
snew_Skin new_Skin;

// ==================== Module base ====================
static uintptr_t Get_module_base() {
    uint32_t count = _dyld_image_count();
    for (int i = 0; i < count; i++) {
        std::string path = (const char *)_dyld_get_image_name(i);
        if (path.find("ShadowTrackerExtra.app/ShadowTrackerExtra") != path.npos) {
            return (uintptr_t)_dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

uintptr_t g_module_base = 0;
uintptr_t getRealOffset(uintptr_t offset) {
    if (g_module_base == 0) g_module_base = Get_module_base();
    return g_module_base + offset;
}

uintptr_t obbbbl() {
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *BundID = [info objectForKey:@"CFBundleIdentifier"];
    if ([BundID containsString:@"com.tencent.ig"]) return getRealOffset(OFFSET_GWORLD_GL);
    if ([BundID containsString:@"kr"]) return getRealOffset(OFFSET_GWORLD_KR);
    if ([BundID containsString:@"rekoo"]) return getRealOffset(OFFSET_GWORLD_TW);
    if ([BundID containsString:@"vn.vng.pubgmobile"]) return getRealOffset(OFFSET_GWORLD_VNG);
    if ([BundID containsString:@"imobile"]) return getRealOffset(OFFSET_GWORLD_BGMI);
    return 0;
}

uintptr_t GetGNames() {
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *BundID = [info objectForKey:@"CFBundleIdentifier"];
    if ([BundID containsString:@"ig"]) return getRealOffset(OFFSET_GNAMES_GL);
    if ([BundID containsString:@"kr"]) return getRealOffset(OFFSET_GNAMES_KR);
    if ([BundID containsString:@"rekoo"]) return getRealOffset(OFFSET_GNAMES_TW);
    if ([BundID containsString:@"vn"]) return getRealOffset(OFFSET_GNAMES_VNG);
    if ([BundID containsString:@"imobile"]) return getRealOffset(OFFSET_GNAMES_BGMI);
    return 0;
}

// ==================== Globals ====================
namespace imgui {
    bool ESP = true; bool Bone = true; bool Box = true; bool Line = true;
    bool Health = true; bool Name = true; bool Distance = true; bool Weapon = true;
    bool TeamID = false; bool EnemyCount = true; bool GameInfo = true;
}
bool ModSkinn = false; bool KillMessage = false; bool DeadBox = false;
float ESPMaxDistance = 350.0f; float SilentAimMaxDistance = 300.0f;
float Cross = 120.0f; float AimSmooth = 2.5f;
bool Enable = false; bool IsNorecoil2 = false; bool IsNocamerashake = false;
bool IsFastSwitch = false; bool textBorder = true;

namespace Settings { static int Tab = 0; }

// ==================== Custom Theme (From Image) ====================
static const ImVec4 ThemeBg       = ImVec4(0.06f, 0.06f, 0.07f, 0.98f);
static const ImVec4 ThemePanel    = ImVec4(0.08f, 0.08f, 0.09f, 1.00f);
static const ImVec4 ThemeStroke   = ImVec4(0.18f, 0.18f, 0.20f, 1.00f);
static const ImVec4 ThemeText     = ImVec4(0.95f, 0.95f, 0.95f, 1.00f);
static const ImVec4 ThemeTextDim  = ImVec4(0.55f, 0.55f, 0.58f, 1.00f);
static const ImVec4 ThemeAccent   = ImVec4(0.85f, 0.85f, 0.85f, 1.00f);
static const ImVec4 ThemeTrack    = ImVec4(0.18f, 0.18f, 0.20f, 1.00f);

@interface metalbiew () <MTKViewDelegate>
@property (nonatomic, strong) id <MTLDevice> device;
@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;
@end

@implementation metalbiew

- (MTKView *)mtkView { return (MTKView *)self.view; }
- (void)loadView { self.view = [[MTKView alloc] initWithFrame:CGRectMake(0, 0, kWidth, kHeight)]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mtkView.device = self.device;
    self.mtkView.delegate = self;
    self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0);
    self.mtkView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
    self.mtkView.clipsToBounds = YES;
}

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];
    if (!self.device) abort();

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    
    // Apply Dark Theme from Image
    ImGuiStyle& style = ImGui::GetStyle();
    style.Colors[ImGuiCol_WindowBg]        = ThemeBg;
    style.Colors[ImGuiCol_ChildBg]         = ThemePanel;
    style.Colors[ImGuiCol_PopupBg]         = ThemePanel;
    style.Colors[ImGuiCol_Border]          = ThemeStroke;
    style.Colors[ImGuiCol_Text]            = ThemeText;
    style.Colors[ImGuiCol_TextDisabled]    = ThemeTextDim;
    style.Colors[ImGuiCol_Button]          = ThemePanel;
    style.Colors[ImGuiCol_ButtonHovered]   = ImVec4(0.12f, 0.12f, 0.14f, 1.0f);
    style.Colors[ImGuiCol_ButtonActive]    = ImVec4(0.16f, 0.16f, 0.18f, 1.0f);
    style.Colors[ImGuiCol_FrameBg]         = ThemeTrack;
    style.Colors[ImGuiCol_SliderGrab]      = ThemeAccent;
    style.Colors[ImGuiCol_SliderGrabActive]= ImVec4(1.0f, 1.0f, 1.0f, 1.0f);
    style.Colors[ImGuiCol_CheckMark]       = ThemeAccent;
    style.Colors[ImGuiCol_Separator]       = ThemeStroke;

    style.WindowRounding    = 12.0f;
    style.ChildRounding     = 8.0f;
    style.FrameRounding     = 4.0f;
    style.GrabRounding      = 8.0f;
    style.WindowPadding     = ImVec2(0, 0);
    style.FramePadding      = ImVec2(10, 8);
    style.ItemSpacing       = ImVec2(10, 12);
    style.WindowBorderSize  = 1.0f;
    
    // Font
    NSString *FontPath = @"/System/Library/Fonts/Core/AvenirNext.ttc";
    io.Fonts->AddFontFromFileTTF(FontPath.UTF8String, 14.0f);
    
    ImGui_ImplMetal_Init(_device);
    return self;
}

// Custom iOS Toggle switch
static bool Toggle(const char* label, bool* v) {
    ImGui::PushID(label);
    ImGui::TextUnformatted(label);
    
    float rowWidth = ImGui::GetContentRegionAvail().x;
    float switchW = 40.0f;
    float switchH = 20.0f;
    
    ImGui::SameLine(rowWidth - switchW);
    ImVec2 p = ImGui::GetCursorScreenPos();
    ImGui::InvisibleButton("##toggle", ImVec2(switchW, switchH));
    bool changed = false;
    if (ImGui::IsItemClicked()) { *v = !*v; changed = true; }
    
    ImDrawList* dl = ImGui::GetWindowDrawList();
    ImU32 bg = *v ? ImGui::GetColorU32(ThemeAccent) : ImGui::GetColorU32(ThemeTrack);
    dl->AddRectFilled(p, ImVec2(p.x + switchW, p.y + switchH), bg, switchH * 0.5f);
    
    float knobX = *v ? (p.x + switchW - switchH * 0.5f - 2.0f) : (p.x + switchH * 0.5f + 2.0f);
    dl->AddCircleFilled(ImVec2(knobX, p.y + switchH * 0.5f), switchH * 0.42f, IM_COL32(240, 240, 245, 255));
    
    ImGui::PopID();
    return changed;
}

// Custom Section Header (Icon + Text)
static void SectionHeader(const char* icon, const char* title) {
    ImDrawList* dl = ImGui::GetWindowDrawList();
    ImVec2 p = ImGui::GetCursorScreenPos();
    // Draw Icon placeholder (circle)
    dl->AddCircleFilled(ImVec2(p.x + 10, p.y + 10), 8.0f, ImGui::GetColorU32(ThemeStroke));
    ImGui::SetCursorPosX(ImGui::GetCursorPosX() + 24);
    ImGui::TextColored(ThemeText, "%s", title);
    ImGui::Spacing();
    ImGui::Spacing();
}

// Custom Slider with inline value box
static void SliderWithBox(const char* label, float* v, float min, float max, const char* fmt) {
    ImGui::TextColored(ThemeTextDim, "%s", label);
    ImGui::SameLine();
    
    // Slider track
    float trackW = ImGui::GetContentRegionAvail().x - 60.0f;
    ImGui::SetNextItemWidth(trackW);
    ImGui::SliderFloat((std::string("##") + label).c_str(), v, min, max, "");
    
    // Value Box (Right aligned)
    ImGui::SameLine();
    ImGui::PushStyleColor(ImGuiCol_ChildBg, ImVec4(0.12f, 0.12f, 0.14f, 1.0f));
    ImGui::BeginChild((std::string("##val") + label).c_str(), ImVec2(45, 22), true, ImGuiWindowFlags_NoScrollbar);
    ImGui::SetCursorPosX(12);
    ImGui::SetCursorPosY(4);
    ImGui::TextColored(ThemeText, fmt, *v);
    ImGui::EndChild();
    ImGui::PopStyleColor();
}

- (void)drawInMTKView:(MTKView*)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;
    io.DeltaTime = 1 / float(view.preferredFramesPerSecond ?: 60);

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor != nil) {
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [renderEncoder pushDebugGroup:@"ImGui"];

        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
        ImGui::NewFrame();

        // Fullscreen background
        ImGui::SetNextWindowPos(ImVec2(0, 0));
        ImGui::SetNextWindowSize(io.DisplaySize);
        ImGui::Begin("##bg", nullptr, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoInputs);
        ImVec2 p = ImGui::GetWindowPos();
        ImDrawList* draw = ImGui::GetWindowDrawList();
        draw->AddRectFilledMultiColor(p, ImVec2(p.x + io.DisplaySize.x, p.y + io.DisplaySize.y),
                                      IM_COL32(0,0,0,200), IM_COL32(0,0,0,200),
                                      IM_COL32(10,10,15,255), IM_COL32(10,10,15,255));
        ImGui::End();

        // Main Menu
        ImGui::SetNextWindowSize(ImVec2(960, 540), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowPos(ImVec2(io.DisplaySize.x * 0.5f, io.DisplaySize.y * 0.5f), ImGuiCond_FirstUseEver, ImVec2(0.5f, 0.5f));
        
        ImGui::PushStyleColor(ImGuiCol_WindowBg, ThemeBg);
        ImGui::PushStyleColor(ImGuiCol_Border, ThemeStroke);
        
        ImGui::Begin("##menu", nullptr, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoScrollbar);
        
        // ================= TOP BAR =================
        ImGui::BeginChild("##TopBar", ImVec2(0, 60), false);
        
        // Logo
        ImGui::SetCursorPos(ImVec2(20, 18));
        ImGui::PushStyleColor(ImGuiCol_Text, ThemeText);
        ImGui::Text("403VIP");
        ImGui::PopStyleColor();
        
        ImGui::SetCursorPos(ImVec2(20, 36));
        ImGui::PushStyleColor(ImGuiCol_Text, ThemeTextDim);
        ImGui::Text("PREMIUM MENU");
        ImGui::PopStyleColor();
        
        // Tabs
        const char* tabs[] = { "Aimbot", "Advanced", "Legit Bot", "Visuals", "Players", "World", "Miscellaneous", "Main", "Scripts" };
        ImGui::SetCursorPos(ImVec2(180, 18));
        
        for (int i = 0; i < 9; i++) {
            ImGui::PushID(i);
            bool isActive = (Settings::Tab == i);
            
            if (isActive) {
                ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.15f, 0.15f, 0.18f, 1.0f));
                ImGui::PushStyleColor(ImGuiCol_Text, ThemeText);
            } else {
                ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0,0,0,0));
                ImGui::PushStyleColor(ImGuiCol_Text, ThemeTextDim);
            }
            
            // Icon placeholder (small circle) + Text
            ImGui::Button(tabs[i], ImVec2(90, 28));
            if (ImGui::IsItemClicked()) Settings::Tab = i;
            
            ImGui::PopStyleColor(2);
            ImGui::SameLine();
            ImGui::PopID();
        }
        
        // Right side icons (search, settings, close)
        ImGui::SetCursorPos(ImVec2(ImGui::GetWindowWidth() - 120, 18));
        ImGui::TextColored(ThemeTextDim, "o  o  X");
        
        ImGui::EndChild();
        
        // Separator line
        ImGui::PushStyleColor(ImGuiCol_Separator, ThemeStroke);
        ImGui::Separator();
        ImGui::PopStyleColor();
        
        // ================= CONTENT =================
        if (Settings::Tab == 0) {
            float cardW = (ImGui::GetContentRegionAvail().x - 30.0f) * 0.5f;
            
            // Top Left Card (AIM ASSIST)
            ImGui::BeginChild("##AimbotCard", ImVec2(cardW, 230), true, ImGuiWindowFlags_NoScrollbar);
            SectionHeader("+", "AIM ASSIST");
            Toggle("Enable aimbot", &Enable);
            Toggle("Show FOV", &textBorder);
            SliderWithBox("FOV SIZE", &Cross, 50.0f, 500.0f, "%.0f");
            SliderWithBox("DISTANCE", &SilentAimMaxDistance, 50.0f, 500.0f, "%.0f");
            ImGui::EndChild();
            
            ImGui::SameLine();
            
            // Top Right Card (SMOOTHING)
            ImGui::BeginChild("##SmoothCard", ImVec2(cardW, 230), true, ImGuiWindowFlags_NoScrollbar);
            SectionHeader("~", "SMOOTHING");
            SliderWithBox("Smooth", &AimSmooth, 1.0f, 10.0f, "%.1f");
            Toggle("Prediction", &IsNorecoil2);
            ImGui::TextColored(ThemeTextDim, "Bone");
            ImGui::SameLine(ImGui::GetContentRegionAvail().x - 120);
            static int boneIdx = 0;
            const char* bones[] = { "Head", "Neck", "Chest", "Pelvis" };
            ImGui::PushItemWidth(110);
            ImGui::Combo("##bone", &boneIdx, bones, 4);
            ImGui::PopItemWidth();
            ImGui::EndChild();
            
            // Bottom Left Card (TRIGGERBOT)
            ImGui::BeginChild("##TriggerCard", ImVec2(cardW, 120), true, ImGuiWindowFlags_NoScrollbar);
            SectionHeader("!", "TRIGGERBOT");
            ImGui::TextColored(ThemeTextDim, "Trigger");
            ImGui::SameLine(ImGui::GetContentRegionAvail().x - 120);
            static int triggerIdx = 0;
            const char* triggers[] = { "Always", "Keybind", "Hold" };
            ImGui::PushItemWidth(110);
            ImGui::Combo("##trigger", &triggerIdx, triggers, 3);
            ImGui::PopItemWidth();
            ImGui::EndChild();
            
            ImGui::SameLine();
            
            // Bottom Right Card (SILENT AIM)
            ImGui::BeginChild("##SilentCard", ImVec2(cardW, 120), true, ImGuiWindowFlags_NoScrollbar);
            SectionHeader("x", "SILENT AIM");
            Toggle("Enable silent", &IsFastSwitch);
            Toggle("Show silent FOV", &IsNocamerashake);
            ImGui::EndChild();
        }
        else if (Settings::Tab == 1) {
            ImGui::Text("Advanced Settings");
        }
        
        // ================= FOOTER =================
        ImGui::SetCursorPosY(ImGui::GetWindowHeight() - 30);
        ImGui::TextColored(ImVec4(0.4f, 0.4f, 0.4f, 1.0f), "403VIP");
        ImGui::SameLine();
        ImGui::TextColored(ImVec4(0.3f, 0.3f, 0.3f, 1.0f), "BECAUSE YOU DESERVE MORE.  PLAY SMART STAY AHEAD.");
        
        ImGui::End();
        ImGui::PopStyleColor(2);

        ImGui::Render();
        ImDrawData* draw_data = ImGui::GetDrawData();
        ImGui_ImplMetal_RenderDrawData(draw_data, commandBuffer, renderEncoder);

        [renderEncoder popDebugGroup];
        [renderEncoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    [commandBuffer commit];
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {}

@end

__attribute__((constructor)) void _init() {}

+ (void)load {
    g_module_base = Get_module_base();
    FName::GNames = (TNameEntryArray *)GetGNames();
    UObject::GUObjectArray = (FUObjectArray *)obbbbl();

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        // RTL_language();
    });
}