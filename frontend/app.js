(() => {
  const cfg = window.NEST_CONFIG || {};
  const hasValidConfig =
    cfg.supabaseUrl &&
    cfg.supabaseAnonKey &&
    !cfg.supabaseUrl.includes("YOUR_PROJECT_REF") &&
    !cfg.supabaseAnonKey.includes("YOUR_SUPABASE_ANON_KEY");

  const DAY_LABELS = ["일", "월", "화", "수", "목", "금", "토"];
  const ROLE_PRIORITY = [
    "HOMESCHOOL_ADMIN",
    "STAFF",
    "TEACHER",
    "GUEST_TEACHER",
    "PARENT"
  ];
  const OAUTH_STORAGE_KEYS = {
    homeschoolId: "nest.oauth.homeschool_id",
    rootFolderId: "nest.oauth.root_folder_id",
    folderPolicy: "nest.oauth.folder_policy",
    result: "nest.oauth.result"
  };

  const els = {
    menuButtons: document.querySelectorAll(".menu-btn"),
    pages: {
      dashboard: document.getElementById("dashboardPage"),
      timetable: document.getElementById("timetablePage"),
      gallery: document.getElementById("galleryPage"),
      drive: document.getElementById("drivePage")
    },
    pageTitle: document.getElementById("pageTitle"),
    pageSubtitle: document.getElementById("pageSubtitle"),

    loginForm: document.getElementById("loginForm"),
    emailInput: document.getElementById("emailInput"),
    passwordInput: document.getElementById("passwordInput"),
    logoutBtn: document.getElementById("logoutBtn"),
    authStatus: document.getElementById("authStatus"),

    homeschoolSelect: document.getElementById("homeschoolSelect"),
    termSelect: document.getElementById("termSelect"),
    classGroupSelect: document.getElementById("classGroupSelect"),

    summaryText: document.getElementById("summaryText"),
    roleText: document.getElementById("roleText"),
    globalStatus: document.getElementById("globalStatus"),

    bootstrapForm: document.getElementById("bootstrapForm"),
    bootstrapHomeschoolName: document.getElementById("bootstrapHomeschoolName"),
    bootstrapTermName: document.getElementById("bootstrapTermName"),
    bootstrapStartDate: document.getElementById("bootstrapStartDate"),
    bootstrapEndDate: document.getElementById("bootstrapEndDate"),
    bootstrapClassName: document.getElementById("bootstrapClassName"),
    bootstrapCourses: document.getElementById("bootstrapCourses"),
    bootstrapStatus: document.getElementById("bootstrapStatus"),
    refreshContextBtn: document.getElementById("refreshContextBtn"),
    refreshAllBtn: document.getElementById("refreshAllBtn"),

    promptInput: document.getElementById("promptInput"),
    generateProposalBtn: document.getElementById("generateProposalBtn"),
    refreshProposalsBtn: document.getElementById("refreshProposalsBtn"),
    proposalStatus: document.getElementById("proposalStatus"),
    proposalList: document.getElementById("proposalList"),
    coursePalette: document.getElementById("coursePalette"),
    timetableBoard: document.getElementById("timetableBoard"),

    uploadForm: document.getElementById("uploadForm"),
    mediaFileInput: document.getElementById("mediaFileInput"),
    mediaTitleInput: document.getElementById("mediaTitleInput"),
    mediaDescInput: document.getElementById("mediaDescInput"),
    mediaChildIdsInput: document.getElementById("mediaChildIdsInput"),
    uploadStatus: document.getElementById("uploadStatus"),
    refreshGalleryBtn: document.getElementById("refreshGalleryBtn"),
    galleryList: document.getElementById("galleryList"),

    startOAuthBtn: document.getElementById("startOAuthBtn"),
    driveForm: document.getElementById("driveForm"),
    rootFolderInput: document.getElementById("rootFolderInput"),
    folderPolicySelect: document.getElementById("folderPolicySelect"),
    driveAccessTokenInput: document.getElementById("driveAccessTokenInput"),
    driveRefreshTokenInput: document.getElementById("driveRefreshTokenInput"),
    driveTokenExpireInput: document.getElementById("driveTokenExpireInput"),
    disconnectDriveBtn: document.getElementById("disconnectDriveBtn"),
    driveStatus: document.getElementById("driveStatus")
  };

  const state = {
    sb: null,
    session: null,
    user: null,
    memberships: [],
    currentRole: null,
    currentHomeschoolId: null,
    terms: [],
    currentTermId: null,
    classGroups: [],
    currentClassGroupId: null,
    courses: [],
    timeSlots: [],
    sessions: [],
    proposals: [],
    proposalSessionsById: {},
    galleryItems: [],
    mediaChildrenByAsset: {},
    driveIntegration: null
  };

  init();

  function init() {
    bindUI();
    setDefaultDates();

    if (!hasValidConfig) {
      setGlobalStatus("config.js 값을 먼저 설정하세요.");
      els.authStatus.textContent = "Supabase 설정 필요";
      disableInteractive(true);
      return;
    }

    state.sb = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey);
    bootstrapAuth();
  }

  function bindUI() {
    els.menuButtons.forEach((btn) => {
      btn.addEventListener("click", () => switchPage(btn.dataset.page));
    });

    els.loginForm.addEventListener("submit", onLogin);
    els.logoutBtn.addEventListener("click", onLogout);

    els.homeschoolSelect.addEventListener("change", async (e) => {
      state.currentHomeschoolId = e.target.value || null;
      state.currentRole = getCurrentRoleForHomeschool(state.currentHomeschoolId);
      refreshRoleUi();
      await loadTermAndBelow();
      await loadDriveIntegration();
      await loadGalleryItems();
    });

    els.termSelect.addEventListener("change", async (e) => {
      state.currentTermId = e.target.value || null;
      await loadClassGroups();
      await loadTimetableAssets();
      await loadSessions();
      await loadProposals();
      renderCoursePalette();
      renderTimetableBoard();
      await loadGalleryItems();
    });

    els.classGroupSelect.addEventListener("change", async (e) => {
      state.currentClassGroupId = e.target.value || null;
      await loadSessions();
      renderTimetableBoard();
      await loadGalleryItems();
    });

    els.bootstrapForm.addEventListener("submit", onBootstrapCreate);
    els.refreshContextBtn.addEventListener("click", loadHomeschoolContext);
    els.refreshAllBtn.addEventListener("click", async () => {
      await loadHomeschoolContext();
      await loadDriveIntegration();
      await loadGalleryItems();
      setGlobalStatus("전체 새로고침 완료");
    });

    els.generateProposalBtn.addEventListener("click", onGenerateProposal);
    els.refreshProposalsBtn.addEventListener("click", loadProposals);

    els.uploadForm.addEventListener("submit", onUploadMedia);
    els.refreshGalleryBtn.addEventListener("click", loadGalleryItems);

    els.startOAuthBtn.addEventListener("click", onStartDriveOAuth);
    els.driveForm.addEventListener("submit", onSaveDriveSettings);
    els.disconnectDriveBtn.addEventListener("click", onDisconnectDrive);

    window.addEventListener("message", onOAuthWindowMessage);
  }

  function setDefaultDates() {
    const today = new Date();
    const end = new Date(today);
    end.setMonth(end.getMonth() + 4);

    els.bootstrapStartDate.value = toDateInput(today);
    els.bootstrapEndDate.value = toDateInput(end);
  }

  async function bootstrapAuth() {
    const {
      data: { session }
    } = await state.sb.auth.getSession();

    await handleSession(session);

    state.sb.auth.onAuthStateChange(async (_event, sessionValue) => {
      await handleSession(sessionValue);
    });
  }

  async function handleSession(session) {
    state.session = session;
    state.user = session?.user || null;

    if (!state.user) {
      resetState();
      disableInteractive(true);
      els.logoutBtn.classList.add("hidden");
      els.authStatus.textContent = "세션 없음";
      renderAll();
      return;
    }

    disableInteractive(false);
    els.logoutBtn.classList.remove("hidden");
    els.authStatus.textContent = state.user.email;

    await loadHomeschoolContext();
  }

  function disableInteractive(disabled) {
    [
      els.homeschoolSelect,
      els.termSelect,
      els.classGroupSelect,
      els.generateProposalBtn,
      els.refreshProposalsBtn,
      els.refreshGalleryBtn,
      els.startOAuthBtn,
      els.disconnectDriveBtn,
      els.refreshContextBtn,
      els.refreshAllBtn
    ].forEach((el) => {
      if (el) el.disabled = disabled;
    });
  }

  function resetState() {
    state.memberships = [];
    state.currentRole = null;
    state.currentHomeschoolId = null;
    state.terms = [];
    state.currentTermId = null;
    state.classGroups = [];
    state.currentClassGroupId = null;
    state.courses = [];
    state.timeSlots = [];
    state.sessions = [];
    state.proposals = [];
    state.proposalSessionsById = {};
    state.galleryItems = [];
    state.mediaChildrenByAsset = {};
    state.driveIntegration = null;
  }

  async function onLogin(e) {
    e.preventDefault();
    const email = els.emailInput.value.trim();
    const password = els.passwordInput.value.trim();

    if (!email || !password) return;

    setGlobalStatus("로그인 중...");

    const { error } = await state.sb.auth.signInWithPassword({ email, password });
    if (error) {
      setGlobalStatus(`로그인 실패: ${error.message}`);
      return;
    }

    setGlobalStatus("로그인 성공");
    els.loginForm.reset();
  }

  async function onLogout() {
    const { error } = await state.sb.auth.signOut();
    if (error) {
      setGlobalStatus(`로그아웃 실패: ${error.message}`);
      return;
    }
    setGlobalStatus("로그아웃 완료");
  }

  async function loadHomeschoolContext() {
    if (!state.user) return;

    const { data, error } = await state.sb
      .from("homeschool_memberships")
      .select("homeschool_id, role, status, homeschools(id, name, timezone)")
      .eq("user_id", state.user.id)
      .eq("status", "ACTIVE");

    if (error) {
      setGlobalStatus(`홈스쿨 목록 로드 실패: ${error.message}`);
      return;
    }

    state.memberships = data || [];

    if (!state.memberships.length) {
      setGlobalStatus("소속 홈스쿨이 없습니다. 빠른 초기세팅으로 생성하세요.");
      state.currentHomeschoolId = null;
      state.currentRole = null;
      state.terms = [];
      state.classGroups = [];
      state.sessions = [];
      renderAll();
      return;
    }

    const validSchoolIds = new Set(state.memberships.map((m) => m.homeschool_id));
    if (!state.currentHomeschoolId || !validSchoolIds.has(state.currentHomeschoolId)) {
      state.currentHomeschoolId = state.memberships[0].homeschool_id;
    }

    state.currentRole = getCurrentRoleForHomeschool(state.currentHomeschoolId);

    renderHomeschoolSelect();
    refreshRoleUi();

    await loadTermAndBelow();
    await loadDriveIntegration();
    await consumeStoredOAuthResult();
    await loadGalleryItems();

    setGlobalStatus("운영 컨텍스트 로드 완료");
  }

  function getCurrentRoleForHomeschool(homeschoolId) {
    const roles = state.memberships
      .filter((m) => m.homeschool_id === homeschoolId)
      .map((m) => m.role);

    for (const role of ROLE_PRIORITY) {
      if (roles.includes(role)) return role;
    }

    return roles[0] || null;
  }

  function isAdminLike() {
    return state.currentRole === "HOMESCHOOL_ADMIN" || state.currentRole === "STAFF";
  }

  function isDriveAdmin() {
    return state.currentRole === "HOMESCHOOL_ADMIN";
  }

  function canUploadMedia() {
    return ["HOMESCHOOL_ADMIN", "STAFF", "TEACHER", "GUEST_TEACHER"].includes(state.currentRole);
  }

  function refreshRoleUi() {
    els.roleText.textContent = state.currentRole || "역할 없음";

    const canBootstrap = isAdminLike() || state.memberships.length === 0;

    if (isAdminLike()) {
      els.summaryText.textContent = "시간표 생성/편집 권한이 활성화되었습니다.";
    } else if (state.memberships.length === 0) {
      els.summaryText.textContent = "아직 홈스쿨이 없습니다. 빠른 초기 세팅으로 첫 홈스쿨을 생성하세요.";
    } else {
      els.summaryText.textContent = "조회 중심 권한입니다. 일부 편집은 제한됩니다.";
    }

    const adminDisable = !isAdminLike();
    els.generateProposalBtn.disabled = adminDisable;
    els.promptInput.disabled = adminDisable;
    els.bootstrapForm.querySelector("button[type=submit]").disabled = !canBootstrap;

    const driveDisable = !isDriveAdmin();
    els.driveForm.querySelector("button[type=submit]").disabled = driveDisable;
    els.disconnectDriveBtn.disabled = driveDisable;
    els.startOAuthBtn.disabled = driveDisable;
    els.rootFolderInput.disabled = driveDisable;
    els.folderPolicySelect.disabled = driveDisable;
    els.driveAccessTokenInput.disabled = driveDisable;
    els.driveRefreshTokenInput.disabled = driveDisable;
    els.driveTokenExpireInput.disabled = driveDisable;

    const uploadDisable = !canUploadMedia();
    els.uploadForm.querySelector("button[type=submit]").disabled = uploadDisable;
  }

  async function loadTermAndBelow() {
    await loadTerms();
    await loadClassGroups();
    await loadTimetableAssets();
    await loadSessions();
    await loadProposals();
    renderCoursePalette();
    renderTimetableBoard();
  }

  async function loadTerms() {
    if (!state.currentHomeschoolId) {
      state.terms = [];
      state.currentTermId = null;
      renderTermSelect();
      return;
    }

    const { data, error } = await state.sb
      .from("terms")
      .select("id, name, status, start_date, end_date")
      .eq("homeschool_id", state.currentHomeschoolId)
      .order("start_date", { ascending: false });

    if (error) {
      setGlobalStatus(`학기 로드 실패: ${error.message}`);
      return;
    }

    state.terms = data || [];

    if (!state.terms.find((t) => t.id === state.currentTermId)) {
      state.currentTermId = state.terms[0]?.id || null;
    }

    renderTermSelect();
  }

  async function loadClassGroups() {
    if (!state.currentTermId) {
      state.classGroups = [];
      state.currentClassGroupId = null;
      renderClassGroupSelect();
      return;
    }

    const { data, error } = await state.sb
      .from("class_groups")
      .select("id, name, term_id")
      .eq("term_id", state.currentTermId)
      .order("name");

    if (error) {
      setGlobalStatus(`반 로드 실패: ${error.message}`);
      return;
    }

    state.classGroups = data || [];

    if (!state.classGroups.find((c) => c.id === state.currentClassGroupId)) {
      state.currentClassGroupId = state.classGroups[0]?.id || null;
    }

    renderClassGroupSelect();
  }

  async function loadTimetableAssets() {
    if (!state.currentHomeschoolId || !state.currentTermId) {
      state.courses = [];
      state.timeSlots = [];
      return;
    }

    const [coursesRes, slotsRes] = await Promise.all([
      state.sb
        .from("courses")
        .select("id, name")
        .eq("homeschool_id", state.currentHomeschoolId)
        .order("name"),
      state.sb
        .from("time_slots")
        .select("id, day_of_week, start_time, end_time")
        .eq("term_id", state.currentTermId)
        .order("day_of_week")
        .order("start_time")
    ]);

    if (coursesRes.error) setGlobalStatus(`과목 로드 실패: ${coursesRes.error.message}`);
    if (slotsRes.error) setGlobalStatus(`슬롯 로드 실패: ${slotsRes.error.message}`);

    state.courses = coursesRes.data || [];
    state.timeSlots = slotsRes.data || [];
  }

  async function loadSessions() {
    if (!state.currentClassGroupId) {
      state.sessions = [];
      return;
    }

    const { data, error } = await state.sb
      .from("class_sessions")
      .select("id, class_group_id, course_id, time_slot_id, title, source_type, status")
      .eq("class_group_id", state.currentClassGroupId)
      .neq("status", "CANCELED");

    if (error) {
      setGlobalStatus(`세션 로드 실패: ${error.message}`);
      state.sessions = [];
      return;
    }

    state.sessions = data || [];
  }

  async function loadProposals() {
    if (!state.currentTermId) {
      state.proposals = [];
      state.proposalSessionsById = {};
      renderProposals();
      return;
    }

    const { data, error } = await state.sb
      .from("timetable_proposals")
      .select("id, prompt, status, created_at")
      .eq("term_id", state.currentTermId)
      .order("created_at", { ascending: false })
      .limit(20);

    if (error) {
      els.proposalStatus.textContent = `생성안 조회 실패: ${error.message}`;
      return;
    }

    state.proposals = data || [];
    state.proposalSessionsById = {};

    const proposalIds = state.proposals.map((p) => p.id);

    if (proposalIds.length) {
      const { data: psData, error: psErr } = await state.sb
        .from("timetable_proposal_sessions")
        .select("id, proposal_id, class_group_id, course_id, time_slot_id")
        .in("proposal_id", proposalIds);

      if (psErr) {
        els.proposalStatus.textContent = `생성안 세부 조회 실패: ${psErr.message}`;
      } else {
        for (const row of psData || []) {
          if (!state.proposalSessionsById[row.proposal_id]) {
            state.proposalSessionsById[row.proposal_id] = [];
          }
          state.proposalSessionsById[row.proposal_id].push(row);
        }
      }
    }

    renderProposals();
  }

  async function onBootstrapCreate(e) {
    e.preventDefault();

    if (!state.user) {
      els.bootstrapStatus.textContent = "로그인이 필요합니다.";
      return;
    }

    const canBootstrap = isAdminLike() || state.memberships.length === 0;
    if (!canBootstrap) {
      els.bootstrapStatus.textContent = "관리자/스태프 권한이 필요합니다.";
      return;
    }

    const homeschoolName = els.bootstrapHomeschoolName.value.trim();
    const termName = els.bootstrapTermName.value.trim();
    const startDate = els.bootstrapStartDate.value;
    const endDate = els.bootstrapEndDate.value;
    const className = els.bootstrapClassName.value.trim();
    const courseNames = parseCommaWords(els.bootstrapCourses.value);

    if (!homeschoolName || !termName || !startDate || !endDate || !className) {
      els.bootstrapStatus.textContent = "필수값을 모두 입력하세요.";
      return;
    }

    els.bootstrapStatus.textContent = "기본 운영 틀 생성 중...";

    let homeschoolId = state.currentHomeschoolId;

    if (!homeschoolId) {
      const { data: hs, error: hsErr } = await state.sb
        .from("homeschools")
        .insert({
          name: homeschoolName,
          owner_user_id: state.user.id,
          timezone: "Asia/Seoul"
        })
        .select("id")
        .single();

      if (hsErr) {
        els.bootstrapStatus.textContent = `홈스쿨 생성 실패: ${hsErr.message}`;
        return;
      }

      homeschoolId = hs.id;
      state.currentHomeschoolId = homeschoolId;

      await sleep(500);
      await loadHomeschoolContext();
    }

    const { data: term, error: termErr } = await state.sb
      .from("terms")
      .insert({
        homeschool_id: homeschoolId,
        name: termName,
        start_date: startDate,
        end_date: endDate,
        status: "DRAFT"
      })
      .select("id")
      .single();

    if (termErr) {
      els.bootstrapStatus.textContent = `학기 생성 실패: ${termErr.message}`;
      return;
    }

    const { data: classGroup, error: classErr } = await state.sb
      .from("class_groups")
      .insert({
        term_id: term.id,
        name: className,
        capacity: 12
      })
      .select("id")
      .single();

    if (classErr) {
      els.bootstrapStatus.textContent = `반 생성 실패: ${classErr.message}`;
      return;
    }

    if (courseNames.length) {
      const rows = courseNames.map((name) => ({
        homeschool_id: homeschoolId,
        name,
        default_duration_min: 50
      }));

      const { error: courseErr } = await state.sb.from("courses").upsert(rows, {
        onConflict: "homeschool_id,name"
      });

      if (courseErr) {
        els.bootstrapStatus.textContent = `과목 생성 실패: ${courseErr.message}`;
        return;
      }
    }

    const defaultSlots = buildDefaultSlots(term.id);
    const { error: slotErr } = await state.sb.from("time_slots").upsert(defaultSlots, {
      onConflict: "term_id,day_of_week,start_time,end_time"
    });

    if (slotErr) {
      els.bootstrapStatus.textContent = `시간 슬롯 생성 실패: ${slotErr.message}`;
      return;
    }

    state.currentTermId = term.id;
    state.currentClassGroupId = classGroup.id;

    await loadHomeschoolContext();
    await loadDriveIntegration();
    await loadGalleryItems();

    els.bootstrapStatus.textContent = "초기 세팅 완료";
    setGlobalStatus("기본 운영 틀을 생성했습니다.");
  }

  function buildDefaultSlots(termId) {
    const times = [
      ["09:30", "10:20"],
      ["10:30", "11:20"],
      ["11:30", "12:20"],
      ["13:30", "14:20"]
    ];
    const days = [1, 2, 3, 4, 5];
    const out = [];

    for (const day of days) {
      for (const t of times) {
        out.push({
          term_id: termId,
          day_of_week: day,
          start_time: t[0],
          end_time: t[1]
        });
      }
    }

    return out;
  }

  async function onGenerateProposal() {
    if (!isAdminLike()) {
      els.proposalStatus.textContent = "관리자/스태프 권한이 필요합니다.";
      return;
    }

    if (!state.currentTermId || !state.currentClassGroupId) {
      els.proposalStatus.textContent = "학기/반을 먼저 선택하세요.";
      return;
    }

    const prompt = els.promptInput.value.trim();
    if (!prompt) {
      els.proposalStatus.textContent = "프롬프트를 입력하세요.";
      return;
    }

    els.proposalStatus.textContent = "생성안 생성 중...";

    let generated = null;

    try {
      const { data, error } = await state.sb.functions.invoke("timetable-assistant-generate", {
        body: {
          term_id: state.currentTermId,
          class_group_id: state.currentClassGroupId,
          prompt
        }
      });

      if (!error && data?.sessions?.length) generated = data;
    } catch (_err) {
      generated = null;
    }

    if (!generated) {
      generated = buildLocalProposal(prompt);
    }

    const { data: proposal, error: pErr } = await state.sb
      .from("timetable_proposals")
      .insert({
        term_id: state.currentTermId,
        prompt,
        generated_by_user_id: state.user.id,
        status: "GENERATED",
        summary_json: {
          source: generated.source || "local",
          hard_conflicts: generated.hard_conflicts || [],
          soft_warnings: generated.soft_warnings || []
        }
      })
      .select("id")
      .single();

    if (pErr) {
      els.proposalStatus.textContent = `생성안 저장 실패: ${pErr.message}`;
      return;
    }

    const rows = (generated.sessions || []).map((s) => ({
      proposal_id: proposal.id,
      class_group_id: s.class_group_id,
      course_id: s.course_id,
      time_slot_id: s.time_slot_id,
      teacher_main_id: s.teacher_main_id || null,
      teacher_assistant_ids_json: s.teacher_assistant_ids_json || [],
      hard_conflicts_json: s.hard_conflicts_json || [],
      soft_warnings_json: s.soft_warnings_json || []
    }));

    if (rows.length) {
      const { error: psErr } = await state.sb.from("timetable_proposal_sessions").insert(rows);
      if (psErr) {
        els.proposalStatus.textContent = `세부 저장 실패: ${psErr.message}`;
        return;
      }
    }

    els.proposalStatus.textContent = `생성 완료 (${rows.length}세션)`;
    await loadProposals();
  }

  function buildLocalProposal(prompt) {
    const lower = prompt.toLowerCase();
    const occupied = new Set(state.sessions.map((s) => s.time_slot_id));
    const freeSlots = state.timeSlots.filter((slot) => !occupied.has(slot.id));

    const pickedCourses = pickCoursesByPrompt(lower);

    const count = Math.min(4, freeSlots.length, pickedCourses.length);
    const sessions = [];

    for (let i = 0; i < count; i += 1) {
      sessions.push({
        class_group_id: state.currentClassGroupId,
        course_id: pickedCourses[i % pickedCourses.length].id,
        time_slot_id: freeSlots[i].id
      });
    }

    const hard = freeSlots.length ? [] : [{ code: "NO_FREE_SLOT", message: "비어 있는 슬롯이 없습니다." }];

    return {
      source: "local",
      sessions,
      hard_conflicts: hard,
      soft_warnings: []
    };
  }

  function pickCoursesByPrompt(lowerPrompt) {
    const mappings = [
      { words: ["국어", "문해", "읽기", "language"], include: "국어" },
      { words: ["수학", "math"], include: "수학" },
      { words: ["과학", "자연", "science"], include: "자연" },
      { words: ["미술", "art"], include: "미술" }
    ];

    const selected = [];

    for (const m of mappings) {
      if (m.words.some((w) => lowerPrompt.includes(w))) {
        const found = state.courses.find((c) => c.name.includes(m.include));
        if (found && !selected.find((s) => s.id === found.id)) selected.push(found);
      }
    }

    if (!selected.length) {
      selected.push(...state.courses.slice(0, 4));
    }

    return selected;
  }

  function renderProposals() {
    els.proposalList.innerHTML = "";

    if (!state.proposals.length) {
      els.proposalStatus.textContent = "생성안이 없습니다.";
      return;
    }

    els.proposalStatus.textContent = `${state.proposals.length}개 생성안`;

    state.proposals.forEach((p) => {
      const sessions = state.proposalSessionsById[p.id] || [];
      const item = document.createElement("div");
      item.className = "proposal-item";

      item.innerHTML = `
        <strong>${escapeHtml(p.prompt)}</strong>
        <p class="hint">${new Date(p.created_at).toLocaleString()} · ${p.status} · ${sessions.length}세션</p>
        <div class="inline-actions">
          <button class="btn-primary" data-action="apply">적용</button>
          <button class="btn-ghost" data-action="discard">폐기</button>
        </div>
      `;

      const applyBtn = item.querySelector('[data-action="apply"]');
      const discardBtn = item.querySelector('[data-action="discard"]');

      applyBtn.disabled = !isAdminLike();
      discardBtn.disabled = !isAdminLike();

      applyBtn.addEventListener("click", () => applyProposal(p.id));
      discardBtn.addEventListener("click", () => setProposalStatus(p.id, "DISCARDED"));

      els.proposalList.appendChild(item);
    });
  }

  async function setProposalStatus(proposalId, status) {
    const { error } = await state.sb
      .from("timetable_proposals")
      .update({ status })
      .eq("id", proposalId);

    if (error) {
      els.proposalStatus.textContent = `상태 변경 실패: ${error.message}`;
      return;
    }

    await loadProposals();
  }

  async function applyProposal(proposalId) {
    if (!isAdminLike()) return;

    const rows = state.proposalSessionsById[proposalId] || [];
    if (!rows.length) {
      els.proposalStatus.textContent = "적용할 세션이 없습니다.";
      return;
    }

    let ok = 0;
    let fail = 0;

    for (const row of rows) {
      const title = `${findCourseName(row.course_id)} 수업`;
      const { error } = await state.sb.from("class_sessions").insert({
        class_group_id: row.class_group_id,
        course_id: row.course_id,
        time_slot_id: row.time_slot_id,
        title,
        source_type: "AI_PROMPT",
        status: "PLANNED",
        created_by_user_id: state.user.id
      });

      if (error) {
        fail += 1;
      } else {
        ok += 1;
      }
    }

    if (ok > 0) await setProposalStatus(proposalId, "APPLIED");

    els.proposalStatus.textContent = `적용 결과: 성공 ${ok}, 실패 ${fail}`;
    await loadSessions();
    renderTimetableBoard();
  }

  function renderCoursePalette() {
    els.coursePalette.innerHTML = "";

    if (!state.courses.length) {
      els.coursePalette.innerHTML = '<p class="hint">과목이 없습니다.</p>';
      return;
    }

    state.courses.forEach((course) => {
      const chip = document.createElement("div");
      chip.className = "course-chip";
      chip.draggable = isAdminLike();
      chip.textContent = course.name;

      chip.addEventListener("dragstart", (e) => {
        e.dataTransfer.setData("application/x-course-id", course.id);
        e.dataTransfer.effectAllowed = "copy";
      });

      els.coursePalette.appendChild(chip);
    });
  }

  function renderTimetableBoard() {
    els.timetableBoard.innerHTML = "";

    if (!state.currentClassGroupId || !state.timeSlots.length) {
      els.timetableBoard.innerHTML = '<p class="hint">학기/반 선택 후 시간표를 확인하세요.</p>';
      return;
    }

    const slots = [...state.timeSlots].sort((a, b) => {
      if (a.day_of_week !== b.day_of_week) return a.day_of_week - b.day_of_week;
      return a.start_time.localeCompare(b.start_time);
    });

    slots.forEach((slot) => {
      const slotEl = document.createElement("div");
      slotEl.className = "slot";
      slotEl.dataset.slotId = slot.id;

      slotEl.innerHTML = `
        <div class="slot-head">
          <strong>${DAY_LABELS[slot.day_of_week] || slot.day_of_week}</strong>
          <span>${shortTime(slot.start_time)}-${shortTime(slot.end_time)}</span>
        </div>
      `;

      state.sessions
        .filter((s) => s.time_slot_id === slot.id)
        .forEach((session) => slotEl.appendChild(createSessionCard(session)));

      slotEl.addEventListener("dragover", (e) => {
        e.preventDefault();
        slotEl.classList.add("drag-over");
      });

      slotEl.addEventListener("dragleave", () => slotEl.classList.remove("drag-over"));

      slotEl.addEventListener("drop", async (e) => {
        e.preventDefault();
        slotEl.classList.remove("drag-over");

        if (!isAdminLike()) return;

        const sessionId = e.dataTransfer.getData("application/x-session-id");
        const courseId = e.dataTransfer.getData("application/x-course-id");

        if (sessionId) {
          await moveSessionToSlot(sessionId, slot.id);
        } else if (courseId) {
          await createSessionByCourse(courseId, slot.id);
        }
      });

      els.timetableBoard.appendChild(slotEl);
    });
  }

  function createSessionCard(session) {
    const card = document.createElement("div");
    card.className = "session-card";
    card.draggable = isAdminLike();

    const courseName = findCourseName(session.course_id);

    card.innerHTML = `
      <div class="session-top">
        <div>
          <strong>${escapeHtml(session.title || courseName)}</strong>
          <span>${escapeHtml(courseName)} · ${session.source_type}</span>
        </div>
        ${isAdminLike() ? '<button class="session-remove" title="삭제">✕</button>' : ""}
      </div>
    `;

    card.addEventListener("dragstart", (e) => {
      if (!isAdminLike()) return;
      e.dataTransfer.setData("application/x-session-id", session.id);
      e.dataTransfer.effectAllowed = "move";
    });

    const removeBtn = card.querySelector(".session-remove");
    if (removeBtn) {
      removeBtn.addEventListener("click", async () => {
        await cancelSession(session.id);
      });
    }

    return card;
  }

  async function createSessionByCourse(courseId, slotId) {
    const conflict = state.sessions.find((s) => s.time_slot_id === slotId);
    if (conflict) {
      setGlobalStatus("동일 반/시간에 이미 수업이 있습니다.");
      return;
    }

    const title = `${findCourseName(courseId)} 수업`;

    const { error } = await state.sb.from("class_sessions").insert({
      class_group_id: state.currentClassGroupId,
      course_id: courseId,
      time_slot_id: slotId,
      title,
      source_type: "MANUAL",
      status: "PLANNED",
      created_by_user_id: state.user.id
    });

    if (error) {
      setGlobalStatus(`수업 생성 실패: ${error.message}`);
      return;
    }

    setGlobalStatus("수업 생성 완료");
    await loadSessions();
    renderTimetableBoard();
  }

  async function moveSessionToSlot(sessionId, slotId) {
    const targetOccupied = state.sessions.find((s) => s.time_slot_id === slotId && s.id !== sessionId);
    if (targetOccupied) {
      setGlobalStatus("대상 슬롯이 이미 사용 중입니다.");
      return;
    }

    const { error } = await state.sb
      .from("class_sessions")
      .update({ time_slot_id: slotId, source_type: "MANUAL" })
      .eq("id", sessionId);

    if (error) {
      setGlobalStatus(`이동 실패: ${error.message}`);
      return;
    }

    setGlobalStatus("세션 이동 완료");
    await loadSessions();
    renderTimetableBoard();
  }

  async function cancelSession(sessionId) {
    const { error } = await state.sb
      .from("class_sessions")
      .update({ status: "CANCELED" })
      .eq("id", sessionId);

    if (error) {
      setGlobalStatus(`세션 취소 실패: ${error.message}`);
      return;
    }

    setGlobalStatus("세션 취소 완료");
    await loadSessions();
    renderTimetableBoard();
  }

  async function onUploadMedia(e) {
    e.preventDefault();

    if (!canUploadMedia()) {
      els.uploadStatus.textContent = "업로드 권한이 없습니다.";
      return;
    }

    if (!state.currentHomeschoolId) {
      els.uploadStatus.textContent = "홈스쿨을 선택하세요.";
      return;
    }

    const file = els.mediaFileInput.files?.[0];
    if (!file) {
      els.uploadStatus.textContent = "파일을 선택하세요.";
      return;
    }

    els.uploadStatus.textContent = "업로드 세션 생성 중...";

    const { data: uploadSession, error: upErr } = await state.sb
      .from("media_upload_sessions")
      .insert({
        homeschool_id: state.currentHomeschoolId,
        uploader_user_id: state.user.id,
        status: "UPLOADING",
        mime_type: file.type || "application/octet-stream",
        size_bytes: file.size
      })
      .select("id")
      .single();

    if (upErr) {
      els.uploadStatus.textContent = `업로드 세션 생성 실패: ${upErr.message}`;
      return;
    }

    let uploadResult;

    try {
      const base64 = await toBase64(file);
      const { data, error } = await state.sb.functions.invoke("google-drive-upload", {
        body: {
          homeschool_id: state.currentHomeschoolId,
          upload_session_id: uploadSession.id,
          file_name: file.name,
          mime_type: file.type || "application/octet-stream",
          file_base64: base64
        }
      });

      if (error) {
        throw error;
      }

      uploadResult = data;
    } catch (err) {
      await state.sb
        .from("media_upload_sessions")
        .update({ status: "FAILED" })
        .eq("id", uploadSession.id);

      els.uploadStatus.textContent = `Drive 업로드 실패: ${err.message || err}`;
      return;
    }

    const { data: mediaAsset, error: mediaErr } = await state.sb
      .from("media_assets")
      .insert({
        homeschool_id: state.currentHomeschoolId,
        upload_session_id: uploadSession.id,
        drive_file_id: uploadResult.drive_file_id,
        drive_web_view_link: uploadResult.drive_web_view_link || null,
        uploader_user_id: state.user.id,
        class_group_id: state.currentClassGroupId,
        title: els.mediaTitleInput.value.trim(),
        description: els.mediaDescInput.value.trim(),
        media_type: file.type.startsWith("video/") ? "VIDEO" : "PHOTO",
        captured_at: new Date().toISOString()
      })
      .select("id")
      .single();

    if (mediaErr) {
      await state.sb
        .from("media_upload_sessions")
        .update({ status: "FAILED" })
        .eq("id", uploadSession.id);

      els.uploadStatus.textContent = `미디어 메타 저장 실패: ${mediaErr.message}`;
      return;
    }

    const childIds = parseCommaIds(els.mediaChildIdsInput.value);
    if (childIds.length) {
      const rows = childIds.map((id) => ({ media_asset_id: mediaAsset.id, child_id: id }));
      const { error: childErr } = await state.sb.from("media_asset_children").insert(rows);
      if (childErr) {
        setGlobalStatus(`child 태깅 일부 실패: ${childErr.message}`);
      }
    }

    await state.sb
      .from("media_upload_sessions")
      .update({ status: "COMPLETED" })
      .eq("id", uploadSession.id);

    els.uploadStatus.textContent = "Drive 업로드 완료";
    els.uploadForm.reset();
    await loadGalleryItems();
  }

  async function loadGalleryItems() {
    if (!state.currentHomeschoolId) {
      state.galleryItems = [];
      renderGallery();
      return;
    }

    let query = state.sb
      .from("media_assets")
      .select(
        "id, title, description, media_type, drive_web_view_link, class_group_id, captured_at"
      )
      .eq("homeschool_id", state.currentHomeschoolId)
      .order("captured_at", { ascending: false })
      .limit(48);

    if (state.currentClassGroupId) {
      query = query.eq("class_group_id", state.currentClassGroupId);
    }

    const { data, error } = await query;

    if (error) {
      setGlobalStatus(`갤러리 로드 실패: ${error.message}`);
      state.galleryItems = [];
      renderGallery();
      return;
    }

    state.galleryItems = data || [];

    const assetIds = state.galleryItems.map((a) => a.id);
    state.mediaChildrenByAsset = {};

    if (assetIds.length) {
      const { data: childRows } = await state.sb
        .from("media_asset_children")
        .select("media_asset_id, child_id")
        .in("media_asset_id", assetIds);

      (childRows || []).forEach((r) => {
        if (!state.mediaChildrenByAsset[r.media_asset_id]) {
          state.mediaChildrenByAsset[r.media_asset_id] = [];
        }
        state.mediaChildrenByAsset[r.media_asset_id].push(r.child_id);
      });
    }

    renderGallery();
  }

  function renderGallery() {
    els.galleryList.innerHTML = "";

    if (!state.galleryItems.length) {
      els.galleryList.innerHTML = '<p class="hint">표시할 갤러리 항목이 없습니다.</p>';
      return;
    }

    state.galleryItems.forEach((item) => {
      const card = document.createElement("article");
      card.className = "gallery-item";
      const childCount = state.mediaChildrenByAsset[item.id]?.length || 0;

      card.innerHTML = `
        <div class="thumb">${item.media_type === "VIDEO" ? "VIDEO" : "PHOTO"}</div>
        <h4>${escapeHtml(item.title || "제목 없음")}</h4>
        <p>${escapeHtml(item.description || "설명 없음")}</p>
        <p>태그된 child: ${childCount}</p>
        <p>${item.captured_at ? new Date(item.captured_at).toLocaleString() : "-"}</p>
        ${
          item.drive_web_view_link
            ? `<p><a href="${escapeAttr(item.drive_web_view_link)}" target="_blank" rel="noreferrer">Drive 열기</a></p>`
            : "<p>Drive 링크 없음</p>"
        }
      `;

      els.galleryList.appendChild(card);
    });
  }

  async function onStartDriveOAuth() {
    if (!isDriveAdmin()) {
      els.driveStatus.textContent = "홈스쿨 관리자 권한이 필요합니다.";
      return;
    }

    if (!state.currentHomeschoolId) {
      els.driveStatus.textContent = "홈스쿨을 선택하세요.";
      return;
    }

    stashOAuthContext();

    const { data, error } = await state.sb.functions.invoke("google-drive-connect-start", {
      body: { homeschool_id: state.currentHomeschoolId }
    });

    if (error) {
      els.driveStatus.textContent = `OAuth URL 생성 실패: ${error.message}`;
      return;
    }

    if (!data?.auth_url) {
      els.driveStatus.textContent = "OAuth URL 응답이 비어 있습니다.";
      return;
    }

    const popup = window.open(
      data.auth_url,
      "nest_google_oauth",
      "popup=yes,width=520,height=760,menubar=no,toolbar=no,location=no,status=no"
    );

    if (!popup) {
      els.driveStatus.textContent = "팝업이 차단되었습니다. 브라우저에서 팝업 허용 후 다시 시도하세요.";
      return;
    }

    els.driveStatus.textContent = "OAuth 인증 창을 열었습니다.";
  }

  function stashOAuthContext() {
    try {
      localStorage.setItem(OAUTH_STORAGE_KEYS.homeschoolId, state.currentHomeschoolId || "");
      localStorage.setItem(OAUTH_STORAGE_KEYS.rootFolderId, (els.rootFolderInput.value || "").trim());
      localStorage.setItem(OAUTH_STORAGE_KEYS.folderPolicy, els.folderPolicySelect.value || "TERM_CLASS_DATE");
    } catch (_) {
      // ignore storage failure
    }
  }

  async function onOAuthWindowMessage(event) {
    if (!event || event.origin !== window.location.origin) return;
    if (!event.data || event.data.type !== "nest-google-oauth-complete") return;

    const payload = event.data.payload || {};
    if (!payload.success) {
      els.driveStatus.textContent = `OAuth 완료 실패: ${payload.error || "알 수 없는 오류"}`;
      return;
    }

    els.driveStatus.textContent = "OAuth 연결이 완료되었습니다. 상태를 다시 불러옵니다.";

    if (payload.root_folder_id) {
      els.rootFolderInput.value = payload.root_folder_id;
    }
    if (payload.folder_policy) {
      els.folderPolicySelect.value = payload.folder_policy;
    }

    await loadDriveIntegration();
  }

  async function consumeStoredOAuthResult() {
    let raw = "";
    try {
      raw = localStorage.getItem(OAUTH_STORAGE_KEYS.result) || "";
    } catch (_) {
      return;
    }

    if (!raw) return;

    try {
      const parsed = JSON.parse(raw);
      if (parsed?.success) {
        setGlobalStatus("Google Drive OAuth 연결이 완료되었습니다.");
        els.driveStatus.textContent = "Google Drive OAuth 연결 완료";
      }
    } catch (_) {
      // ignore malformed payload
    } finally {
      try {
        localStorage.removeItem(OAUTH_STORAGE_KEYS.result);
      } catch (_) {
        // ignore
      }
    }
  }

  async function loadDriveIntegration() {
    if (!state.currentHomeschoolId) {
      state.driveIntegration = null;
      renderDriveStatus();
      return;
    }

    const baseSelect = "id, status, root_folder_id, folder_policy, connected_at";
    let data;
    let error;

    const rich = await state.sb
      .from("drive_integrations")
      .select(
        "id, status, root_folder_id, folder_policy, connected_at, google_access_token, google_refresh_token, google_token_expires_at"
      )
      .eq("homeschool_id", state.currentHomeschoolId)
      .maybeSingle();

    if (!rich.error) {
      data = rich.data;
      error = null;
    } else {
      const fallback = await state.sb
        .from("drive_integrations")
        .select(baseSelect)
        .eq("homeschool_id", state.currentHomeschoolId)
        .maybeSingle();

      data = fallback.data;
      error = fallback.error;
    }

    if (error) {
      setGlobalStatus(`Drive 상태 로드 실패: ${error.message}`);
      return;
    }

    state.driveIntegration = data || null;
    renderDriveStatus();
  }

  async function onSaveDriveSettings(e) {
    e.preventDefault();

    if (!isDriveAdmin()) {
      els.driveStatus.textContent = "홈스쿨 관리자 권한이 필요합니다.";
      return;
    }

    if (!state.currentHomeschoolId) {
      els.driveStatus.textContent = "홈스쿨을 선택하세요.";
      return;
    }

    const payload = {
      homeschool_id: state.currentHomeschoolId,
      provider: "GOOGLE_DRIVE",
      status: "CONNECTED",
      root_folder_id: els.rootFolderInput.value.trim(),
      folder_policy: els.folderPolicySelect.value,
      connected_by_user_id: state.user.id,
      connected_at: new Date().toISOString(),
      google_access_token: normalizeNullableText(els.driveAccessTokenInput.value),
      google_refresh_token: normalizeNullableText(els.driveRefreshTokenInput.value),
      google_token_expires_at: normalizeNullableDateTime(els.driveTokenExpireInput.value)
    };

    const { error } = await state.sb
      .from("drive_integrations")
      .upsert(payload, { onConflict: "homeschool_id" });

    if (error) {
      els.driveStatus.textContent = `Drive 설정 저장 실패: ${error.message}`;
      return;
    }

    els.driveStatus.textContent = "Drive 설정 저장 완료";
    await loadDriveIntegration();
  }

  async function onDisconnectDrive() {
    if (!isDriveAdmin()) {
      els.driveStatus.textContent = "홈스쿨 관리자 권한이 필요합니다.";
      return;
    }

    if (!state.currentHomeschoolId) return;

    const { error } = await state.sb
      .from("drive_integrations")
      .update({
        status: "DISCONNECTED",
        root_folder_id: null,
        folder_policy: null,
        google_access_token: null,
        google_refresh_token: null,
        google_token_expires_at: null
      })
      .eq("homeschool_id", state.currentHomeschoolId);

    if (error) {
      els.driveStatus.textContent = `Drive 해제 실패: ${error.message}`;
      return;
    }

    els.driveStatus.textContent = "Drive 연동 해제 완료";
    await loadDriveIntegration();
  }

  function renderDriveStatus() {
    if (!state.driveIntegration) {
      els.driveStatus.textContent = "연동 정보 없음";
      els.rootFolderInput.value = "";
      els.folderPolicySelect.value = "TERM_CLASS_DATE";
      els.driveAccessTokenInput.value = "";
      els.driveRefreshTokenInput.value = "";
      els.driveTokenExpireInput.value = "";
      return;
    }

    els.rootFolderInput.value = state.driveIntegration.root_folder_id || "";
    els.folderPolicySelect.value = state.driveIntegration.folder_policy || "TERM_CLASS_DATE";

    const hasAccess = !!state.driveIntegration.google_access_token;
    const hasRefresh = !!state.driveIntegration.google_refresh_token;

    els.driveAccessTokenInput.value = state.driveIntegration.google_access_token || "";
    els.driveRefreshTokenInput.value = state.driveIntegration.google_refresh_token || "";

    if (state.driveIntegration.google_token_expires_at) {
      els.driveTokenExpireInput.value = toDateTimeLocalInput(
        new Date(state.driveIntegration.google_token_expires_at)
      );
    } else {
      els.driveTokenExpireInput.value = "";
    }

    const connectedAt = state.driveIntegration.connected_at
      ? new Date(state.driveIntegration.connected_at).toLocaleString()
      : "-";

    els.driveStatus.textContent = `상태: ${state.driveIntegration.status} · 연결시각: ${connectedAt} · access_token:${
      hasAccess ? "있음" : "없음"
    } · refresh_token:${hasRefresh ? "있음" : "없음"}`;
  }

  function renderHomeschoolSelect() {
    renderSelect(
      els.homeschoolSelect,
      state.memberships.map((m) => ({
        value: m.homeschool_id,
        label: m.homeschools?.name || m.homeschool_id
      })),
      state.currentHomeschoolId
    );
  }

  function renderTermSelect() {
    renderSelect(
      els.termSelect,
      state.terms.map((t) => ({
        value: t.id,
        label: `${t.name} (${t.status})`
      })),
      state.currentTermId
    );
  }

  function renderClassGroupSelect() {
    renderSelect(
      els.classGroupSelect,
      state.classGroups.map((g) => ({ value: g.id, label: g.name })),
      state.currentClassGroupId
    );
  }

  function renderSelect(selectEl, options, selected) {
    selectEl.innerHTML = "";

    if (!options.length) {
      const opt = document.createElement("option");
      opt.value = "";
      opt.textContent = "선택 항목 없음";
      selectEl.appendChild(opt);
      selectEl.value = "";
      return;
    }

    options.forEach((o) => {
      const opt = document.createElement("option");
      opt.value = o.value;
      opt.textContent = o.label;
      selectEl.appendChild(opt);
    });

    const exists = options.find((o) => o.value === selected);
    selectEl.value = exists ? exists.value : options[0].value;

    if (selectEl === els.homeschoolSelect) state.currentHomeschoolId = selectEl.value;
    if (selectEl === els.termSelect) state.currentTermId = selectEl.value;
    if (selectEl === els.classGroupSelect) state.currentClassGroupId = selectEl.value;
  }

  function renderAll() {
    renderHomeschoolSelect();
    renderTermSelect();
    renderClassGroupSelect();
    refreshRoleUi();
    renderCoursePalette();
    renderProposals();
    renderTimetableBoard();
    renderGallery();
    renderDriveStatus();
  }

  function switchPage(page) {
    const pageText = {
      dashboard: ["대시보드", "운영 컨텍스트와 기본 세팅을 관리합니다."],
      timetable: ["시간표 스튜디오", "채팅 생성안과 수동 드래그 편집을 함께 사용합니다."],
      gallery: ["갤러리", "교사 업로드와 학부모/교사 열람을 관리합니다."],
      drive: ["Google Drive", "기관 Drive 연동 및 보관 정책을 관리합니다."]
    };

    els.menuButtons.forEach((btn) => {
      btn.classList.toggle("active", btn.dataset.page === page);
    });

    Object.entries(els.pages).forEach(([k, v]) => {
      v.classList.toggle("active", k === page);
    });

    els.pageTitle.textContent = pageText[page][0];
    els.pageSubtitle.textContent = pageText[page][1];
  }

  function setGlobalStatus(text) {
    els.globalStatus.textContent = text;
  }

  function findCourseName(courseId) {
    return state.courses.find((c) => c.id === courseId)?.name || "미지정 과목";
  }

  function shortTime(v) {
    return String(v || "").slice(0, 5);
  }

  function parseCommaWords(raw) {
    return (raw || "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
  }

  function parseCommaIds(raw) {
    return parseCommaWords(raw);
  }

  function normalizeNullableText(v) {
    const t = (v || "").trim();
    return t ? t : null;
  }

  function normalizeNullableDateTime(v) {
    if (!v) return null;
    const d = new Date(v);
    if (Number.isNaN(d.getTime())) return null;
    return d.toISOString();
  }

  function toDateInput(date) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, "0");
    const d = String(date.getDate()).padStart(2, "0");
    return `${y}-${m}-${d}`;
  }

  function toDateTimeLocalInput(date) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, "0");
    const d = String(date.getDate()).padStart(2, "0");
    const h = String(date.getHours()).padStart(2, "0");
    const mi = String(date.getMinutes()).padStart(2, "0");
    return `${y}-${m}-${d}T${h}:${mi}`;
  }

  function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  function escapeHtml(str) {
    return String(str)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }

  function escapeAttr(str) {
    return escapeHtml(str);
  }

  function toBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const raw = String(reader.result || "");
        const marker = "base64,";
        const idx = raw.indexOf(marker);
        if (idx < 0) {
          reject(new Error("base64 변환 실패"));
          return;
        }
        resolve(raw.slice(idx + marker.length));
      };
      reader.onerror = () => reject(reader.error || new Error("파일 읽기 실패"));
      reader.readAsDataURL(file);
    });
  }
})();
