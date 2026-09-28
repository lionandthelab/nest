#!/usr/bin/env python3
import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FRONTEND_DIR = os.path.abspath(os.path.join(BASE_DIR, '..', '..'))
SHOTS_DIR = os.path.join(FRONTEND_DIR, 'shots', 'appstore_ui')
ASSETS_3D_DIR = os.path.join(FRONTEND_DIR, 'assets', '3d')
OUTPUT_DIR = os.path.join(FRONTEND_DIR, 'ios', 'fastlane', 'screenshots', 'ko')

os.makedirs(OUTPUT_DIR, exist_ok=True)

# System Font path on macOS
FONT_PATH = '/System/Library/Fonts/AppleSDGothicNeo.ttc'

def get_font(size, weight='bold'):
    index = 6 if weight == 'bold' else (4 if weight == 'semibold' else (2 if weight == 'medium' else 0))
    try:
        return ImageFont.truetype(FONT_PATH, size, index=index)
    except Exception:
        return ImageFont.load_default()

def create_gradient(width, height, top_color, bottom_color):
    base = Image.new('RGB', (width, height), top_color)
    top_r, top_g, top_b = top_color
    bot_r, bot_g, bot_b = bottom_color
    
    # Linear vertical interpolation
    draw = ImageDraw.Draw(base)
    for y in range(height):
        factor = y / float(height)
        r = int(top_r + (bot_r - top_r) * factor)
        g = int(top_g + (bot_g - top_g) * factor)
        b = int(top_b + (bot_b - top_b) * factor)
        draw.line([(0, y), (width, y)], fill=(r, g, b))
    return base

def add_ambient_glow(img, center_x, center_y, radius, color, alpha=0.18):
    glow = Image.new('RGBA', img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    r, g, b = color
    a = int(alpha * 255)
    
    # Draw concentric circles or a filled circle then blur
    draw.ellipse([
        center_x - radius, center_y - radius,
        center_x + radius, center_y + radius
    ], fill=(r, g, b, a))
    
    glow = glow.filter(ImageFilter.GaussianBlur(radius=radius // 2))
    img.alpha_composite(glow)

def round_corners(image, radius):
    mask = Image.new('L', image.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, image.size[0], image.size[1]], radius=radius, fill=255)
    result = image.copy()
    result.putalpha(mask)
    return result

def create_device_mockup(raw_screenshot_path, device_width=1020, device_height=2200):
    # Outer device frame with shadow
    border_thick = 16
    screen_w = device_width - (border_thick * 2)
    screen_h = device_height - (border_thick * 2)
    radius_outer = 64
    radius_inner = 50

    # Load and resize screenshot
    raw = Image.open(raw_screenshot_path).convert('RGBA')
    raw_aspect = raw.width / float(raw.height)
    target_aspect = screen_w / float(screen_h)

    # Scale to fit width and crop/fit height
    scale = screen_w / float(raw.width)
    scaled_h = int(raw.height * scale)
    scaled_raw = raw.resize((screen_w, scaled_h), Image.Resampling.LANCZOS)
    
    screen_img = Image.new('RGBA', (screen_w, screen_h), (255, 255, 255, 255))
    screen_img.paste(scaled_raw, (0, 0))

    # Mask inner screen with rounded corners
    screen_rounded = round_corners(screen_img, radius_inner)

    # Bezel base
    bezel = Image.new('RGBA', (device_width, device_height), (0, 0, 0, 0))
    draw_bezel = ImageDraw.Draw(bezel)
    
    # Outer frame: dark metallic obsidian (#1C1D21) with thin rim
    draw_bezel.rounded_rectangle(
        [0, 0, device_width, device_height],
        radius=radius_outer,
        fill=(28, 29, 33, 255),
        outline=(70, 72, 80, 200),
        width=3
    )
    
    # Paste inner screen
    bezel.paste(screen_rounded, (border_thick, border_thick), screen_rounded)

    # Create realistic shadow
    shadow_margin = 80
    shadow_w = device_width + shadow_margin * 2
    shadow_h = device_height + shadow_margin * 2
    shadow_layer = Image.new('RGBA', (shadow_w, shadow_h), (0, 0, 0, 0))
    draw_shadow = ImageDraw.Draw(shadow_layer)
    draw_shadow.rounded_rectangle(
        [shadow_margin, shadow_margin + 20, shadow_margin + device_width, shadow_margin + device_height + 20],
        radius=radius_outer,
        fill=(60, 35, 30, 75)
    )
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=38))
    
    # Composite bezel on shadow
    mockup = Image.new('RGBA', (shadow_w, shadow_h), (0, 0, 0, 0))
    mockup.paste(shadow_layer, (0, 0), shadow_layer)
    mockup.paste(bezel, (shadow_margin, shadow_margin), bezel)
    
    return mockup, shadow_margin

def compose_iphone_card(
    output_filename,
    raw_screenshot_name,
    tag_text,
    title_line1,
    title_line2,
    subtitle_text,
    floating_3d_name,
    glow_color=(247, 157, 142)
):
    canvas_w = 1290
    canvas_h = 2796
    
    # 1. Warm Radiant Background
    bg = create_gradient(canvas_w, canvas_h, (255, 250, 247), (247, 237, 230))
    card = bg.convert('RGBA')
    
    # 2. Ambient glows
    add_ambient_glow(card, 200, 260, 380, glow_color, alpha=0.18)
    add_ambient_glow(card, 1100, 480, 420, (230, 215, 245), alpha=0.15)
    add_ambient_glow(card, 645, 1800, 600, (255, 245, 235), alpha=0.30)
    
    draw = ImageDraw.Draw(card)
    
    # 3. Floating 3D Element (Top Right)
    if floating_3d_name:
        path_3d = os.path.join(ASSETS_3D_DIR, floating_3d_name)
        if os.path.exists(path_3d):
            icon_3d = Image.open(path_3d).convert('RGBA')
            icon_size = 230
            icon_3d = icon_3d.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
            
            # Subtle 3D shadow
            shadow_3d = Image.new('RGBA', (icon_size + 40, icon_size + 40), (0, 0, 0, 0))
            sdraw = ImageDraw.Draw(shadow_3d)
            sdraw.ellipse([20, 24, icon_size + 20, icon_size + 24], fill=(70, 40, 35, 60))
            shadow_3d = shadow_3d.filter(ImageFilter.GaussianBlur(radius=16))
            
            pos_x = canvas_w - icon_size - 60
            pos_y = 120
            card.paste(shadow_3d, (pos_x - 20, pos_y - 10), shadow_3d)
            card.paste(icon_3d, (pos_x, pos_y), icon_3d)

    # 4. Marketing Header
    # Tag Badge
    font_tag = get_font(34, 'bold')
    tag_bbox = font_tag.getbbox(tag_text)
    tag_text_w = tag_bbox[2] - tag_bbox[0]
    tag_pad_h = 32
    tag_pad_v = 14
    tag_w = tag_text_w + (tag_pad_h * 2)
    tag_h = (tag_bbox[3] - tag_bbox[1]) + (tag_pad_v * 2)
    
    tag_x = 90
    tag_y = 140
    draw.rounded_rectangle(
        [tag_x, tag_y, tag_x + tag_w, tag_y + tag_h],
        radius=tag_h // 2,
        fill=(255, 240, 235, 240),
        outline=(245, 195, 185, 220),
        width=2
    )
    draw.text((tag_x + tag_pad_h, tag_y + tag_pad_v - 2), tag_text, font=font_tag, fill=(195, 88, 70))

    # Main Headline (Two lines)
    font_title = get_font(74, 'bold')
    line_spacing = 98
    title_start_y = 245
    draw.text((90, title_start_y), title_line1, font=font_title, fill=(42, 30, 26))
    draw.text((90, title_start_y + line_spacing), title_line2, font=font_title, fill=(42, 30, 26))

    # Subtitle
    font_subtitle = get_font(36, 'medium')
    sub_y = title_start_y + (line_spacing * 2) + 20
    draw.text((90, sub_y), subtitle_text, font=font_subtitle, fill=(115, 96, 90))

    # 5. Realistic Device Mockup
    raw_path = os.path.join(SHOTS_DIR, raw_screenshot_name)
    if os.path.exists(raw_path):
        device_w = 1040
        device_h = 2240
        mockup, shadow_m = create_device_mockup(raw_path, device_width=device_w, device_height=device_h)
        
        # Position device so it starts below subtitle and extends gracefully to bottom
        mockup_x = (canvas_w - mockup.width) // 2
        mockup_y = 590 - shadow_m
        card.paste(mockup, (mockup_x, mockup_y), mockup)

    # 6. Save as RGB PNG
    final_card = card.convert('RGB')
    out_path = os.path.join(OUTPUT_DIR, output_filename)
    final_card.save(out_path, format='PNG', optimize=True)
    print(f"Generated iPhone card: {out_path} ({final_card.size})")

def compose_ipad_cards():
    ipad_w = 2064
    ipad_h = 2752
    
    # iPad 1: Home Dashboard
    card1 = create_gradient(ipad_w, ipad_h, (255, 250, 247), (247, 237, 230)).convert('RGBA')
    add_ambient_glow(card1, 300, 300, 500, (247, 157, 142), alpha=0.18)
    draw1 = ImageDraw.Draw(card1)
    
    # Tag
    font_tag = get_font(42, 'bold')
    draw1.text((120, 140), "NEST · 홈스쿨링 올인원 대시보드", font=font_tag, fill=(195, 88, 70))
    # Headline
    font_h1 = get_font(84, 'bold')
    draw1.text((120, 220), "우리 아이 홈스쿨의 모든 것, 한눈에 스마트하게", font=font_h1, fill=(42, 30, 26))
    # Subtitle
    font_sub = get_font(42, 'medium')
    draw1.text((120, 330), "오늘의 수업과 개인 일정, 학사일정과 홈스쿨 팁까지 올인원 대시보드", font=font_sub, fill=(115, 96, 90))
    
    # Place 3D icon
    p3d = os.path.join(ASSETS_3D_DIR, 'study_books_3d.png')
    if os.path.exists(p3d):
        ic = Image.open(p3d).convert('RGBA').resize((280, 280), Image.Resampling.LANCZOS)
        card1.paste(ic, (ipad_w - 360, 120), ic)

    # Device Mockup for iPad
    raw_home = os.path.join(SHOTS_DIR, 'raw_01_home.png')
    if os.path.exists(raw_home):
        mock, sm = create_device_mockup(raw_home, device_width=1320, device_height=2250)
        card1.paste(mock, ((ipad_w - mock.width) // 2, 480 - sm), mock)

    out1 = os.path.join(OUTPUT_DIR, 'ipad-01-home.png')
    card1.convert('RGB').save(out1, format='PNG', optimize=True)
    print(f"Generated iPad card: {out1}")

    # iPad 2: Timetable
    card2 = create_gradient(ipad_w, ipad_h, (255, 250, 247), (247, 237, 230)).convert('RGBA')
    add_ambient_glow(card2, 1700, 300, 500, (144, 213, 175), alpha=0.18)
    draw2 = ImageDraw.Draw(card2)
    
    draw2.text((120, 140), "NEST · 주간 시간표 & 일정 관리", font=font_tag, fill=(195, 88, 70))
    draw2.text((120, 220), "과목별 주간 시간표와 구글 캘린더 연동", font=font_h1, fill=(42, 30, 26))
    draw2.text((120, 330), "월~금 교시별 수업 시간표와 학사일정, 개인 일정을 한눈에 확인하세요", font=font_sub, fill=(115, 96, 90))
    
    p3d_cal = os.path.join(ASSETS_3D_DIR, 'calendar_3d.png')
    if os.path.exists(p3d_cal):
        ic = Image.open(p3d_cal).convert('RGBA').resize((280, 280), Image.Resampling.LANCZOS)
        card2.paste(ic, (ipad_w - 360, 120), ic)

    raw_time = os.path.join(SHOTS_DIR, 'raw_02_timetable.png')
    if os.path.exists(raw_time):
        mock, sm = create_device_mockup(raw_time, device_width=1320, device_height=2250)
        card2.paste(mock, ((ipad_w - mock.width) // 2, 480 - sm), mock)

    out2 = os.path.join(OUTPUT_DIR, 'ipad-02-community.png')
    card2.convert('RGB').save(out2, format='PNG', optimize=True)
    print(f"Generated iPad card: {out2}")

def main():
    print("Composing iPhone 6.7\" / 6.9\" marketing screenshots...")
    # Card 1: Dashboard
    compose_iphone_card(
        output_filename='01-parent-home.png',
        raw_screenshot_name='raw_01_home.png',
        tag_text='NEST · 홈스쿨링 올인원 플랫폼',
        title_line1='우리 아이 홈스쿨의 모든 것,',
        title_line2='Nest 하나로 스마트하게',
        subtitle_text='오늘의 수업 · 개인 일정 · 공지사항 대시보드',
        floating_3d_name='study_books_3d.png',
        glow_color=(247, 157, 142)
    )

    # Card 2: Timetable
    compose_iphone_card(
        output_filename='02-parent-timetable.png',
        raw_screenshot_name='raw_02_timetable.png',
        tag_text='NEST · 스마트 시간표 & 일정',
        title_line1='과목별 주간 시간표와',
        title_line2='학사일정을 한눈에 쏙',
        subtitle_text='요일별 교시 시간표부터 구글 캘린더 연동까지',
        floating_3d_name='calendar_3d.png',
        glow_color=(144, 213, 175)
    )

    # Card 3: Album
    compose_iphone_card(
        output_filename='03-album.png',
        raw_screenshot_name='raw_03_album.png',
        tag_text='NEST · 무제한 드라이브 앨범',
        title_line1='구글 드라이브 무제한 연동,',
        title_line2='우리 반 활동 사진첩',
        subtitle_text='반별·활동별 자동 분류와 원본 고화질 아카이빙',
        floating_3d_name='empty_nest_3d.png',
        glow_color=(184, 224, 249)
    )

    # Card 4: Community & Members
    compose_iphone_card(
        output_filename='04-teacher-hub.png',
        raw_screenshot_name='raw_04_members.png',
        tag_text='NEST · 쉬운 공동체 & 멤버 관리',
        title_line1='초대 코드 하나로',
        title_line2='학부모·교사 공동체 완성',
        subtitle_text='간편한 가입 승인과 반 배정, 세분화된 권한 제어',
        floating_3d_name='achievement_star_3d.png',
        glow_color=(212, 154, 106)
    )

    # Card 5: Tips & Portfolio
    compose_iphone_card(
        output_filename='05-tips.png',
        raw_screenshot_name='raw_05_tips.png',
        tag_text='NEST · 홈스쿨 팁 & 포트폴리오',
        title_line1='매일 전하는 홈스쿨 팁과',
        title_line2='학기별 학습 포트폴리오',
        subtitle_text='따뜻한 3D 감성으로 채워가는 우리 아이 성장 기록',
        floating_3d_name='tips_lightbulb_3d.png',
        glow_color=(247, 157, 142)
    )

    print("Composing iPad 13\" marketing screenshots...")
    compose_ipad_cards()
    print("All App Store marketing cards generated successfully!")

if __name__ == '__main__':
    main()
