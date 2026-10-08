extends Node2D
const Field = preload("res://scripts/field.gd")
var game = TrailGame.new()
var field = Field.new()
var save_directory = "user://saves"
var session_started: bool = false
var ui: Control
var status: Label
var target_label: Label
var toast: Label
var toast_timer: float = 0
var party_buttons: Array = []
var modal: PanelContainer
var modal_content: VBoxContainer
var modal_kind: String = ""
var was_in_town: bool = true
var save_failed: bool = false
var hud_panel: PanelContainer
var target_panel: PanelContainer
var toast_panel: PanelContainer

func _ready() -> void:
    game.new_game()
    game.paused = true
    field.scale = Vector2.ONE
    field.setup(game)
    add_child(field)
    build_ui()
    game.notice.connect(show_notice)
    game.autosave_requested.connect(save_progress)
    get_tree().auto_accept_quit = false
    open_menu("slots")
    refresh_hud()
    if "--pixel-demo" in OS.get_cmdline_user_args():
        save_directory = "user://pixel-prototype-saves"
        choose_slot(0)

func pixel_box(asset: String, margin: int = 8) -> StyleBoxTexture:
    var box = StyleBoxTexture.new()
    box.texture = load("res://assets/pixel/" + asset + ".png")
    for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
        box.set_texture_margin(side, 5)
        box.set_content_margin(side, margin)
    return box

func build_ui() -> void:
    var canvas = CanvasLayer.new()
    add_child(canvas)
    ui = Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var theme = Theme.new()
    theme.default_font = field.font
    theme.default_font_size = 12
    for state in ["normal", "hover", "pressed", "disabled", "focus"]:
        var asset = "button"
        if state == "hover":
            asset = "hover"
        elif state == "pressed":
            asset = "pressed"
        var style = pixel_box(asset, 6)
        style.content_margin_top = 4
        style.content_margin_bottom = 4
        theme.set_stylebox(state, "Button", style)
        theme.set_color("font_" + state + "_color", "Button", Color("182820"))
    theme.set_color("font_color", "Button", Color("182820"))
    theme.set_color("font_disabled_color", "Button", Color("a0a898"))
    theme.set_stylebox("panel", "PanelContainer", pixel_box("panel", 10))
    theme.set_stylebox("scroll", "VScrollBar", pixel_box("button", 0))
    theme.set_stylebox("grabber", "VScrollBar", pixel_box("pressed", 0))
    theme.set_stylebox("grabber_highlight", "VScrollBar", pixel_box("hover", 0))
    theme.set_color("font_color", "Label", Color("182820"))
    ui.theme = theme
    canvas.add_child(ui)
    hud_panel = PanelContainer.new()
    hud_panel.position = Vector2(4, 4)
    hud_panel.size = Vector2(126, 25)
    hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(hud_panel)
    status = Label.new()
    hud_panel.add_child(status)
    target_panel = PanelContainer.new()
    target_panel.position = Vector2(4, 234)
    target_panel.size = Vector2(312, 50)
    ui.add_child(target_panel)
    target_label = Label.new()
    target_panel.add_child(target_label)
    var menu = button(ui, "메뉴", func(): open_menu("pause"))
    menu.position = Vector2(271, 4)
    # Party is available in its menu and number keys, not a permanent six-card overlay.
    for i in 6:
        var b = button(ui, "", func(): switch_party(i))
        b.hide()
        party_buttons.append(b)
    toast_panel = PanelContainer.new()
    toast_panel.position = Vector2(4, 234)
    toast_panel.size = Vector2(312, 50)
    toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(toast_panel)
    toast = Label.new()
    toast.custom_minimum_size = Vector2(290, 26)
    toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    toast_panel.add_child(toast)
    modal = PanelContainer.new()
    modal.position = Vector2(22, 35)
    modal.size = Vector2(276, 194)
    ui.add_child(modal)
    var scroll = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(254, 172)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    modal.add_child(scroll)
    modal_content = VBoxContainer.new()
    modal_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    modal_content.add_theme_constant_override("separation", 6)
    scroll.add_child(modal_content)

func button(parent: Node, text: String, callback: Callable) -> Button:
    var b = Button.new()
    b.text = text
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(callback)
    parent.add_child(b)
    return b

func line(text: String, size: int = 18) -> Label:
    var l = Label.new()
    l.text = text
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size.x = 238
    l.add_theme_font_size_override("font_size", 12)
    modal_content.add_child(l)
    return l

func clear_menu() -> void:
    for child in modal_content.get_children():
        modal_content.remove_child(child)
        child.queue_free()

func open_menu(kind: String) -> void:
    if not session_started and kind != "slots":
        return
    if modal.visible and modal_kind == kind and kind != "slots":
        close_menu()
        return
    game.paused = true
    modal_kind = kind
    field.sfx.silence()
    modal.show()
    render_menu()
    refresh_hud()

func close_menu() -> void:
    if not session_started:
        return
    modal.hide()
    modal_kind = ""
    game.paused = false
    refresh_hud()

func render_menu() -> void:
    clear_menu()
    match modal_kind:
        "slots":
            line("새봄의 기록 / MONSTER TRAIL", 28)
            line("새봄마을에서 잎귀와 첫 모험을 시작하세요.")
            line("저장 슬롯을 선택하세요. 이어하기는 마을에서 시작합니다.")
            for i in 3:
                var exists = slot_exists(i)
                button(modal_content, "%d번 · %s" % [i + 1, "이어하기" if exists else "새 모험"], func(): choose_slot(i))
            line("WASD로 오른쪽 들판에 나가 몬스터를 클릭하세요.\n약해지면 가까이서 F로 포획 · 마을에서 E로 회복", 16)
        "party":
            line("동료와 가방 · 시간이 멈춰 있습니다", 25)
            line("포획 도구 %d  /  회복약 %d  /  %d 잎전" % [game.tools, game.potions, game.coins])
            for i in game.party.size():
                var mon = game.party[i]
                line("%d. %s · Lv.%d · 종족 %s / 개체 평가 %d\n체력 %d/%d · 경험치 %d/%d" % [i + 1, game.spec(mon).name, mon.level, game.spec(mon).rank, game.appraisal(mon), mon.hp, game.max_hp(mon), mon.xp, game.xp_needed(mon)])
                var row = HBoxContainer.new()
                modal_content.add_child(row)
                button(row, "출전", func(): switch_party(i); render_menu())
                button(row, "회복약", func(): game.use_potion(i); render_menu())
                for slot in mon.order:
                    var s = int(slot)
                    if s >= mon.moves.size():
                        continue
                    var skill = game.catalog.skills[mon.moves[s]]
                    var skills_row = VBoxContainer.new()
                    modal_content.add_child(skills_row)
                    button(skills_row, "%s %s\n시전 %.1fs / 재사용 %.1fs" % ["ON" if mon.enabled[s] else "OFF", skill.name, skill.windup, skill.cooldown], func(): mon.enabled[s] = not mon.enabled[s]; render_menu())
                    button(skills_row, "우선 사용", func(): mon.order.erase(s); mon.order.push_front(s); render_menu())
        "town":
            line("새봄마을 · 여행자의 쉼터", 26)
            line("%d 잎전 · 포획 도구 %d · 회복약 %d" % [game.coins, game.tools, game.potions])
            button(modal_content, "동료 모두 회복 · 무료", func(): game.heal_all(); save_progress(); show_notice("동료들이 모두 회복했습니다."); render_menu())
            button(modal_content, "포획 도구 +1 · 15 잎전", func(): purchase("tool"))
            button(modal_content, "회복약 +1 · 25 잎전", func(): purchase("potion"))
            button(modal_content, "보관함 · %d마리" % game.storage.size(), func(): open_menu("storage"))
            button(modal_content, "마을에서 쉬며 들판 다시 탐색", func(): game.heal_all(); game.reset_field(); save_progress(); close_menu())
        "storage":
            line("보관함 · 마을에서만 교환할 수 있습니다", 25)
            line("파티가 가득 차면 현재 출전 동료와 교환합니다.")
            for i in game.storage.size():
                var mon = game.storage[i]
                button(modal_content, "%s Lv.%d · 파티로" % [game.spec(mon).name, mon.level], func(): game.trade_storage(i, game.active); render_menu())
            if game.storage.is_empty():
                line("파티 6마리 이후에 포획한 동료가 이곳에서 쉽니다.")
        "journal":
            line("인연 도감 · %d / 200종" % game.caught.size(), 26)
            line("첫 지역의 18종 설계 초안 · 그림과 생태 문장은 교정 중입니다.", 16)
            for definition in game.catalog.species:
                if int(definition.region) != 0:
                    continue
                line("%s %s · %s\n%s" % ["●" if definition.id in game.caught else "○", definition.name, definition.rank, definition.lore], 17)
        "map":
            line("새봄의 길", 26)
            line("서쪽: 새봄마을 (회복·상점·보관함)\n중앙: 꽃바람 들판 (잎귀 서식)\n북동쪽: 길지기의 시험 (E로 도전)")
            line("보스까지의 방향: %s · 거리 약 %d" % ["북동쪽" if game.player.x < 1408 else "북쪽", game.player.distance_to(Vector2(1530, 300))])
            line("전체 계획은 8지역 + 최종 지역입니다. 현재 지형은 첫 지역만 구현했습니다.")
            if 0 in game.beaten:
                line("새봄의 길이 열렸습니다! 다음 지역 지형은 제작 중입니다.")
        "boss":
            line("길지기의 시험", 26)
            line("첫 지역 보스 전투 원형입니다. 시작하면 경기장 안에서 싸웁니다.\n전멸하면 마을에서 회복하며 소지금 5%를 사용합니다.")
            button(modal_content, "도전 시작", begin_boss)
        "pause":
            line("잠시 쉬어가기", 26)
            line("저장 슬롯 %d · %.0f분 플레이\n메뉴를 닫으면 모험이 계속됩니다." % [game.save_slot + 1, game.play_time / 60])
            button(modal_content, "동료 / 가방  [Tab]", func(): open_menu("party"))
            button(modal_content, "도감 [J]", func(): open_menu("journal"))
            button(modal_content, "지도 [M]", func(): open_menu("map"))
            button(modal_content, "효과음: %s" % ("켜짐" if field.sfx.enabled else "꺼짐"), func(): field.sfx.toggle(); render_menu())
            button(modal_content, "저장 · 안전할 때만", manual_save)
            button(modal_content, "저장 후 종료 · 안전할 때만", save_and_quit)
            button(modal_content, "저장하지 않고 종료…", func(): open_menu("quit"))
            line("전투 중에는 동료와 함께 마을로 돌아와 저장하세요.\n포획·보스 승리·마을 도착은 자동 저장됩니다.", 16)
        "quit":
            line("저장하지 않고 종료할까요?", 26)
            line("마지막 자동·수동 저장 이후의 진행은 사라집니다.")
            button(modal_content, "저장하지 않고 종료", func(): get_tree().quit())
    if modal_kind != "slots":
        button(modal_content, "돌아가기 · Esc", close_menu)

func slot_exists(slot: int) -> bool:
    var path = save_directory.path_join("slot_%d.json" % slot)
    return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")

func choose_slot(slot: int) -> bool:
    if slot_exists(slot):
        if not game.load_game(slot, save_directory):
            show_notice("저장을 읽을 수 없습니다. 원본을 유지합니다. 다른 슬롯을 선택하세요.")
            return false
    else:
        game.new_game(int(Time.get_unix_time_from_system()))
        game.save_slot = slot
    session_started = true
    close_menu()
    save_progress()
    show_notice("WASD 이동 / E 쉼터 / Tab 동료\n들판에서 클릭 지휘, F 포획.")
    return true

func save_progress() -> void:
    if not session_started:
        return
    var error = game.save_game(-1, save_directory)
    save_failed = error != OK
    if save_failed:
        show_notice("저장 실패 (%d). 저장 폴더 권한과 여유 공간을 확인하세요." % error)

func safe_to_save() -> bool:
    if game.boss_active or not game.pending_capture.is_empty():
        return false
    for enemy in game.enemies:
        if enemy.mon.hp > 0 and enemy.alert:
            return false
    return true

func manual_save() -> bool:
    if not safe_to_save():
        show_notice("전투가 끝난 안전한 곳에서 저장할 수 있습니다.")
        return false
    save_progress()
    if not save_failed:
        show_notice("%d번 슬롯에 저장했습니다." % (game.save_slot + 1))
    return not save_failed

func save_and_quit() -> void:
    if manual_save():
        get_tree().quit()

func purchase(kind: String) -> void:
    if not game.buy(kind):
        show_notice("잎전이 부족하거나 마을 밖입니다.")
    render_menu()

func switch_party(index: int) -> void:
    if session_started:
        game.switch_to(index)
        refresh_hud()

func interact() -> void:
    if game.in_town():
        open_menu("town")
    elif Field.ARENA.has_point(game.player) and not game.boss_active:
        open_menu("boss")
    else:
        show_notice("마을이나 북동쪽 시험터에서 E를 눌러보세요.")

func begin_boss() -> void:
    if game.start_boss():
        game.player = Vector2(1500, 320)
        game.companion = Vector2(1540, 320)
        # Ordinary wildlife does not participate in the enclosed trial.
        for enemy in game.enemies:
            if not enemy.boss:
                enemy.alert = false
        close_menu()

func show_notice(message: String) -> void:
    toast.text = message
    toast_timer = 5
    toast_panel.show()

func refresh_hud() -> void:
    status.text = "새봄마을" if game.in_town() else "꽃바람 들판"
    if save_failed:
        status.text += " 저장 오류"
    hud_panel.visible = not modal.visible
    for i in 6:
        var b: Button = party_buttons[i]
        b.disabled = not session_started or i >= game.party.size()
        if i < game.party.size():
            var mon = game.party[i]
            b.text = "%d %s%s %d\nHP %d/%d" % [i + 1, ">" if i == game.active else "", game.spec(mon).name, mon.level, mon.hp, game.max_hp(mon)]
        else:
            b.text = "%d  -\n빈 자리" % (i + 1)
    var target = game.enemy_by_id(game.target_id)
    target_panel.visible = not target.is_empty() and not modal.visible
    target_label.text = "" if target.is_empty() else "%s HP %d/%d\n%s" % [game.spec(target.mon).name, target.mon.hp, target.max_hp, "보스 · 포획 불가" if target.boss else "F 포획 %.0f%% · 거리 %d / 220" % [game.capture_chance(target) * 100, game.player.distance_to(target.pos)]]
    if game.switch_timer > 0:
        target_label.text += "\n교체 대기 %.1f초" % game.switch_timer

func _physics_process(dt: float) -> void:
    if not session_started or game.paused:
        return
    var direction = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
    game.move_player(direction, dt)
    game.tick(dt)
    field.advance(dt, direction)
    var town_now = game.in_town()
    if town_now and not was_in_town:
        game.request_autosave()
    was_in_town = town_now
    refresh_hud()

func _process(dt: float) -> void:
    toast_panel.visible = toast_timer > 0 and not modal.visible and game.target_id.is_empty()
    if toast_timer > 0:
        toast_timer -= dt
        if toast_timer <= 0:
            toast.text = ""

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        var key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
        if key == KEY_ESCAPE:
            if modal.visible:
                close_menu()
            else:
                open_menu("pause")
            return
        if not session_started:
            return
        if key in [KEY_TAB, KEY_J, KEY_M]:
            open_menu({KEY_TAB: "party", KEY_J: "journal", KEY_M: "map"}[key])
            return
        if game.paused:
            return
        if key >= KEY_1 and key <= KEY_6:
            switch_party(key - KEY_1)
        elif key == KEY_F:
            game.begin_capture()
        elif key == KEY_E:
            interact()
        elif key == KEY_F5:
            manual_save()
    elif event is InputEventMouseButton and event.pressed and session_started and not game.paused:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            game.recall()
        elif event.button_index == MOUSE_BUTTON_LEFT:
            var p = field.world_from_screen(event.position)
            var nearest: Dictionary = {}
            var distance = 42.0
            for enemy in game.enemies:
                var d = (enemy.pos - Vector2(0, 22)).distance_to(p)
                if enemy.mon.hp > 0 and d < distance:
                    distance = d
                    nearest = enemy
            if not nearest.is_empty():
                game.command_attack(nearest.mon.uid)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        if not session_started:
            get_tree().quit()
        else:
            open_menu("pause")
    elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and session_started:
        if not modal.visible:
            open_menu("pause")
