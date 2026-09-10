const app = document.querySelector("#app");
const modal = document.querySelector("#modal");
const esc = (value) =>
  String(value ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const label = (value) =>
  String(value || "Unknown")
    .replaceAll("_", " ")
    .toLowerCase()
    .replace(/^./, (c) => c.toUpperCase());
const state = { page: "overview", data: {}, errors: {}, organization: null };
let stream;
let scanning = false;
let qrUrl;
const names = {
  parks: "Parks",
  routes: "Routes",
  drivers: "Drivers",
  vehicles: "Vehicles",
  "organization-units": "Organization units",
  roles: "Roles",
  users: "Staff",
};
const badge = (value) =>
  `<span class="badge ${value === "ACTIVE" || value === "REGISTERED" ? "green" : ""}">${esc(label(value))}</span>`;
function notice(message) {
  document.querySelector("#notice").textContent = message;
}
async function api(path, body) {
  const response = await fetch(`/gateway/${path}`, {
    method: body === undefined ? "GET" : "POST",
    credentials: "same-origin",
    headers: { "Content-Type": "application/json" },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const result = await response.json();
  if (!response.ok) {
    if (
      response.status === 401 &&
      !path.startsWith("auth/login") &&
      location.pathname !== "/verify"
    ) {
      modal.close();
      login();
    }
    throw new Error(
      Array.isArray(result.message)
        ? result.message.join(". ")
        : result.message || "Request failed",
    );
  }
  return result;
}
function brand() {
  return '<a class="brand" href="/" aria-label="RouteMate home"><span class="mark">R<span>↗</span></span>RouteMate<span class="brand-dot">.</span></a>';
}
function login() {
  state.data = {};
  state.organization = null;
  state.signedIn = false;
  app.innerHTML = `<main id="main" class="login"><section class="login-story">${brand()}<div><p class="eyebrow">CONNECTED TRANSPORT OPERATIONS</p><h1>A clearer view.<br>A better journey.</h1><p>Manage your parks, people and vehicles.<br>Give passengers a way to check before they board.</p><div class="route-art" aria-hidden="true"><span>Park</span><i></i><span>Route</span><i></i><span>Journey ↗</span></div></div><small>RouteMate staff workspace</small></section><section class="login-panel"><div><p class="eyebrow">WELCOME BACK</p><h2>Sign in to your organization</h2><p class="muted">Use the staff account provided by your administrator.</p><form id="login-form">${input("organizationCode", "Organization code", "text", true, 'autocomplete="organization" maxlength="30"')}${input("email", "Email address", "email", true, 'autocomplete="username"')}${input("password", "Password", "password", true, 'autocomplete="current-password"')}<p class="form-error" role="alert"></p><button class="primary" type="submit">Sign in <span>→</span></button></form><a class="passenger-link" href="/verify">Travelling today? Check a vehicle ↗</a></div></section></main>`;
  document.querySelector("#login-form").onsubmit = async (event) => {
    event.preventDefault();
    const form = event.currentTarget;
    const button = form.querySelector("button");
    button.disabled = true;
    try {
      await api("auth/login", Object.fromEntries(new FormData(form)));
      form.reset();
      await load();
    } catch (error) {
      form.querySelector(".form-error").textContent = error.message;
    } finally {
      button.disabled = false;
    }
  };
}
async function load() {
  await api("auth/me");
  state.signedIn = true;
  const keys = [...Object.keys(names), "organizations/current"];
  await Promise.all(
    keys.map(async (key) => {
      try {
        const data = await api(key);
        if (key === "organizations/current") state.organization = data;
        else state.data[key] = data;
        delete state.errors[key];
      } catch (error) {
        state.errors[key] = error.message;
        state.data[key] = [];
      }
    }),
  );
  if (state.signedIn) render();
}
function input(name, title, type = "text", required = true, attrs = "") {
  return `<label>${title}<input name="${name}" type="${type}" ${required ? "required" : ""} ${attrs}></label>`;
}
function select(name, title, entries) {
  return `<label>${title}<select name="${name}" required><option value="">Select ${title.toLowerCase()}</option>${entries.map(([id, text]) => `<option value="${esc(id)}">${esc(text)}</option>`).join("")}</select></label>`;
}
const choices = (key, predicate = () => true) =>
  (state.data[key] || [])
    .filter(predicate)
    .map((item) => [
      item.id,
      item.name || item.plateNumber || `${item.firstName} ${item.lastName}`,
    ]);
function render() {
  const page = state.page;
  app.innerHTML = `<div class="workspace"><aside>${brand()}<p class="nav-label">WORKSPACE</p><nav>${[["overview", "Overview"], ...Object.entries(names)].map(([key, title]) => `<button class="nav-item ${key === page ? "selected" : ""}" data-page="${key}" ${key === page ? 'aria-current="page"' : ""}><span>${{ overview: "◫", parks: "⌖", routes: "↗", drivers: "♙", vehicles: "▱", roles: "◇", users: "♧" }[key] || "⊞"}</span>${title}</button>`).join("")}</nav><div class="sidebar-bottom"><a href="/verify" target="_blank" rel="noopener">Passenger verification ↗</a><p>Organization access<br><strong>${esc(state.organization?.name || "Staff workspace")}</strong></p><button id="logout" class="quiet">Sign out</button></div></aside><div class="content"><header><span>Operations <span class="muted">/ ${esc(names[page] || "Overview")}</span></span><span class="account"><i></i> Staff workspace</span></header><main id="main"><div class="page-heading"><div><p class="eyebrow">YOUR TRANSPORT NETWORK</p><h1>${esc(names[page] || "Operations overview")}</h1><p class="muted">${page === "overview" ? "Keep registrations, assignments and passenger checks connected." : "Live records within your organization and assigned scope."}</p></div><button id="reload" class="secondary">↻ Refresh</button></div>${page === "overview" ? overview() : listPage(page)}</main><footer>RouteMate · Organization-scoped operations <span>Lists show up to 100 accessible records.</span></footer></div></div>`;
  document.querySelectorAll("[data-page]").forEach(
    (button) =>
      (button.onclick = () => {
        state.page = button.dataset.page;
        render();
      }),
  );
  document.querySelector("#logout").onclick = async () => {
    try {
      await api("auth/logout", {});
      notice("Signed out");
      login();
    } catch (error) {
      notice(error.message);
    }
  };
  document.querySelector("#reload").onclick = () =>
    load().catch((error) => notice(error.message));
  document
    .querySelectorAll("[data-create]")
    .forEach(
      (button) => (button.onclick = () => createForm(button.dataset.create)),
    );
  document
    .querySelectorAll("[data-manage]")
    .forEach(
      (button) =>
        (button.onclick = () =>
          manageVehicle(button.dataset.manage).catch((error) =>
            notice(error.message),
          )),
    );
  document.querySelectorAll("[data-status]").forEach(
    (button) =>
      (button.onclick = () =>
        confirmAction(
          "Change registration status",
          `This will ${button.dataset.status} this registration. Compliance status is managed separately.`,
          async () => {
            await api(
              `${page}/${button.dataset.id}/${button.dataset.status}`,
              {},
            );
            await load();
          },
        )),
  );
  const search = document.querySelector("#search");
  if (search)
    search.oninput = () => {
      const query = search.value.toLowerCase();
      document
        .querySelectorAll("tbody tr")
        .forEach(
          (row) =>
            (row.hidden = !row.textContent.toLowerCase().includes(query)),
        );
    };
}
function overview() {
  return `<div class="stats">${["parks", "routes", "drivers", "vehicles"].map((key) => `<button class="stat" data-page="${key}"><span>${names[key]}</span><strong>${state.errors[key] ? "—" : (state.data[key]?.length ?? 0)}</strong><small>Accessible records <span>↗</span></small></button>`).join("")}</div><section class="panel"><div class="section-heading"><div><h2>Get a vehicle ready for verification</h2><p class="muted">Follow the registration workflow in order.</p></div><span class="tag">OPERATIONS GUIDE</span></div><div class="steps">${[
    [
      "parks",
      "01",
      "Set up a park",
      "Choose the organization unit responsible for operations.",
    ],
    [
      "drivers",
      "02",
      "Register people & vehicles",
      "Add the records, then activate approved registrations.",
    ],
    [
      "vehicles",
      "03",
      "Connect assignments",
      "Assign an active primary driver and an operating route.",
    ],
    [
      "vehicles",
      "04",
      "Issue a vehicle QR",
      "Print the code for passengers to check the registry.",
    ],
  ]
    .map(
      ([page, n, title, detail]) =>
        `<button data-page="${page}"><span class="step-number">${n}</span><h3>${title}</h3><p>${detail}</p><span class="step-arrow">↗</span></button>`,
    )
    .join(
      "",
    )}</div></section><div class="overview-bottom"><section class="panel"><p class="eyebrow">PASSENGER ACCESS</p><h2>Check before boarding</h2><p class="muted">Passengers can scan a RouteMate QR without signing in. The result shows registration, assignments and reported compliance status.</p><a class="text-link" href="/verify" target="_blank" rel="noopener">Open passenger verification ↗</a></section><section class="note"><span class="note-symbol">i</span><h3>Registration has a defined scope</h3><p>A registered result confirms registry entries and current assignments. It does not certify roadworthiness or guarantee a safe journey.</p></section></div>`;
}
function listPage(key) {
  const rows = state.data[key] || [];
  const create = [
    "parks",
    "routes",
    "drivers",
    "vehicles",
    "organization-units",
  ].includes(key);
  const columns = {
    parks: ["Park", "Type", "Status"],
    routes: ["Route", "Origin → destination", "Status"],
    drivers: ["Driver", "Registration", "Compliance", "Actions"],
    vehicles: [
      "Plate number",
      "Type / seats",
      "Registration",
      "Compliance",
      "Actions",
    ],
    "organization-units": ["Unit", "Type", "Status"],
    roles: ["Role", "Code", "Permissions"],
    users: ["Staff member", "Email", "Status"],
  }[key];
  const cells = (row) => {
    const statusAction = `<button class="table-action" data-id="${esc(row.id)}" data-status="${row.registrationStatus === "ACTIVE" ? "suspend" : "activate"}">${row.registrationStatus === "ACTIVE" ? "Suspend" : "Activate"}</button>`;
    switch (key) {
      case "parks":
        return [esc(row.name), esc(label(row.parkType)), badge(row.status)];
      case "routes":
        return [
          esc(row.name),
          `${esc(row.originName)} → ${esc(row.destinationName)}`,
          badge(row.status),
        ];
      case "drivers":
        return [
          esc(`${row.firstName} ${row.lastName}`),
          badge(row.registrationStatus),
          badge(row.complianceStatus),
          statusAction,
        ];
      case "vehicles":
        return [
          `<strong>${esc(row.plateNumber)}</strong>`,
          `${esc(label(row.vehicleType))} / ${esc(row.passengerCapacity)}`,
          badge(row.registrationStatus),
          badge(row.complianceStatus),
          `<button class="table-action" data-manage="${esc(row.id)}">Manage →</button>${statusAction}`,
        ];
      case "organization-units":
        return [esc(row.name), esc(label(row.unitType)), badge(row.status)];
      case "roles":
        return [
          esc(row.name),
          esc(row.code),
          esc((row.permissions || []).join(", ")),
        ];
      default:
        return [
          esc(row.name || `${row.firstName || ""} ${row.lastName || ""}`),
          esc(row.email),
          badge(row.status),
        ];
    }
  };
  return `<section class="panel records"><div class="section-heading"><label class="search-label"><span class="sr-only">Search loaded records</span><input id="search" type="search" placeholder="Search ${names[key].toLowerCase()}…"></label>${create ? `<button class="primary" data-create="${key}">+ Add ${key === "organization-units" ? "unit" : key.slice(0, -1)}</button>` : ""}</div>${
    state.errors[key]
      ? `<div class="empty"><h2>Records unavailable</h2><p>${esc(state.errors[key])}</p></div>`
      : rows.length
        ? `<div class="table-wrap"><table><thead><tr>${columns.map((c) => `<th scope="col">${c}</th>`).join("")}</tr></thead><tbody>${rows
            .map(
              (row) =>
                `<tr>${cells(row)
                  .map((cell) => `<td>${cell}</td>`)
                  .join("")}</tr>`,
            )
            .join("")}</tbody></table></div>`
        : `<div class="empty"><span>⊞</span><h2>No ${names[key].toLowerCase()} to show</h2><p>${create ? "Add a record to get started. You will only see records your role can access." : "There are no accessible records in this view."}</p></div>`
  }</section>`;
}
function dialog(title, html) {
  if (qrUrl) {
    URL.revokeObjectURL(qrUrl);
    qrUrl = null;
  }
  modal.innerHTML = `<div class="dialog-heading"><h2>${esc(title)}</h2><button class="quiet" id="close-modal" aria-label="Close dialog">✕</button></div>${html}`;
  document.querySelector("#close-modal").onclick = () => modal.close();
  if (!modal.open) modal.showModal();
}
function confirmAction(title, message, action) {
  dialog(
    title,
    `<p>${esc(message)}</p><p class="form-error" role="alert"></p><button class="primary" id="confirm">Confirm</button>`,
  );
  document.querySelector("#confirm").onclick = async (event) => {
    event.currentTarget.disabled = true;
    try {
      await action();
      modal.close();
      notice("Change saved");
    } catch (error) {
      modal.querySelector(".form-error").textContent = error.message;
      modal.querySelector("#confirm").disabled = false;
    }
  };
}
function createForm(key) {
  const park = select(
    "parkId",
    "Park",
    choices("parks", (row) => row.status === "ACTIVE"),
  );
  let fields;
  if (key === "parks")
    fields =
      input("name", "Park name") +
      select(
        "organizationUnitId",
        "Organization unit",
        choices("organization-units"),
      ) +
      select(
        "parkType",
        "Park type",
        ["TERMINAL", "MOTOR_PARK", "BUS_STOP", "LOADING_POINT", "DEPOT"].map(
          (v) => [v, label(v)],
        ),
      ) +
      input(
        "capacity",
        "Capacity (optional)",
        "number",
        false,
        'min="1" max="100000"',
      ) +
      input(
        "longitude",
        "Longitude (optional)",
        "number",
        false,
        'step="any" min="-180" max="180"',
      ) +
      input(
        "latitude",
        "Latitude (optional)",
        "number",
        false,
        'step="any" min="-90" max="90"',
      );
  if (key === "routes")
    fields =
      park +
      input("name", "Route name") +
      input("originName", "Origin") +
      input("destinationName", "Destination") +
      '<label>Route coordinates (optional)<textarea name="coordinates" rows="3" placeholder="Longitude,latitude — one point per line"></textarea><small>At least two points, in travel order. Longitude first.</small></label>';
  if (key === "drivers")
    fields =
      park +
      input("firstName", "First name") +
      input("lastName", "Last name") +
      input("phone", "Phone number", "tel", true, 'pattern="[+]?[0-9]{7,15}"');
  if (key === "vehicles")
    fields =
      park +
      input("plateNumber", "Plate number") +
      select(
        "vehicleType",
        "Vehicle type",
        [
          "DANFO",
          "KOROPE",
          "MINIBUS",
          "BUS",
          "TAXI",
          "TRICYCLE",
          "SHUTTLE",
          "OTHER",
        ].map((v) => [v, label(v)]),
      ) +
      input(
        "passengerCapacity",
        "Passenger capacity",
        "number",
        true,
        'min="1" max="200"',
      ) +
      input("make", "Make (optional)", "text", false) +
      input("model", "Model (optional)", "text", false) +
      input("colour", "Colour (optional)", "text", false);
  if (key === "organization-units")
    fields =
      input("code", "Unit code") +
      input("name", "Unit name") +
      select(
        "unitType",
        "Unit type",
        ["NATIONAL", "STATE_CHAPTER", "ZONE", "BRANCH", "LOCAL_UNIT"].map(
          (v) => [v, label(v)],
        ),
      ) +
      `<label>Parent unit (optional)<select name="parentUnitId"><option value="">No parent</option>${choices(
        key,
      )
        .map(([id, name]) => `<option value="${esc(id)}">${esc(name)}</option>`)
        .join("")}</select></label>`;
  dialog(
    `Add ${key === "organization-units" ? "organization unit" : key.slice(0, -1)}`,
    `<form id="create-form" class="form-grid">${fields}<p class="form-error full" role="alert"></p><button class="primary full" type="submit">Save record</button></form>`,
  );
  document.querySelector("#create-form").onsubmit = async (event) => {
    event.preventDefault();
    const form = event.currentTarget;
    const button = form.querySelector("button");
    button.disabled = true;
    try {
      const data = Object.fromEntries(
        [...new FormData(form)].filter(([, value]) => value !== ""),
      );
      for (const field of ["capacity", "passengerCapacity"])
        if (data[field]) data[field] = Number(data[field]);
      if (data.longitude !== undefined || data.latitude !== undefined) {
        if (data.longitude === undefined || data.latitude === undefined)
          throw new Error("Enter both longitude and latitude");
        data.location = {
          longitude: Number(data.longitude),
          latitude: Number(data.latitude),
        };
        delete data.longitude;
        delete data.latitude;
      }
      if (data.coordinates) {
        data.points = data.coordinates
          .trim()
          .split("\n")
          .map((line) => {
            const parts = line.split(",");
            if (
              parts.length !== 2 ||
              parts.some((v) => !v.trim() || !Number.isFinite(Number(v)))
            )
              throw new Error("Use longitude,latitude on each line");
            return { longitude: Number(parts[0]), latitude: Number(parts[1]) };
          });
        delete data.coordinates;
      }
      await api(key, data);
      modal.close();
      notice("Record saved");
      await load();
    } catch (error) {
      form.querySelector(".form-error").textContent = error.message;
    } finally {
      button.disabled = false;
    }
  };
}
async function manageVehicle(id) {
  const vehicle = state.data.vehicles.find((row) => row.id === id);
  const assignments = await api(`vehicles/${id}/assignments`);
  const assignmentRows = (key, kind) =>
    assignments[key]
      .filter((row) => row.status === "ACTIVE")
      .map((row) => {
        const record = state.data[
          kind === "driver" ? "drivers" : "routes"
        ].find((r) => r.id === row[`${kind}Id`]);
        const name =
          record?.name ||
          (record
            ? `${record.firstName} ${record.lastName}`
            : "Assigned record");
        return `<div class="assignment-row"><span>${esc(name)}</span><button class="table-action" data-end="${kind}-assignments/${esc(row.id)}/end">End assignment</button></div>`;
      })
      .join("") || '<p class="muted">No active assignment.</p>';
  dialog(
    `Manage ${vehicle.plateNumber}`,
    `<p>${badge(vehicle.registrationStatus)} ${badge(vehicle.complianceStatus)} <span class="muted">compliance</span></p><h3>Primary driver</h3>${assignmentRows("drivers", "driver")}<form data-assign="driver">${select(
      "driverId",
      "Active driver",
      choices("drivers", (d) => d.registrationStatus === "ACTIVE"),
    )}<button class="secondary">Assign driver</button></form><h3>Operating routes</h3>${assignmentRows("routes", "route")}<form data-assign="route">${select(
      "routeId",
      "Route",
      choices("routes", (r) => r.status === "ACTIVE"),
    )}<small>The route must operate from this vehicle’s park.</small><button class="secondary">Assign route</button></form><hr><h3>Passenger verification QR</h3><p class="muted">Requires an active vehicle, primary driver and route. Issuing a new QR replaces the previous code.</p><form id="qr-form">${input("expiresInDays", "Valid for (days)", "number", true, 'min="1" max="365" value="30"')}<button class="primary">Issue / replace QR</button></form><button class="quiet danger" id="revoke">Revoke current QR</button><p class="form-error" role="alert"></p>`,
  );
  const error = (err) => {
    modal.querySelector(".form-error").textContent = err.message;
  };
  modal.querySelectorAll("[data-assign]").forEach(
    (form) =>
      (form.onsubmit = async (event) => {
        event.preventDefault();
        const button = form.querySelector("button");
        button.disabled = true;
        try {
          await api(
            `vehicles/${id}/${form.dataset.assign}-assignments`,
            Object.fromEntries(new FormData(form)),
          );
          await manageVehicle(id);
        } catch (err) {
          error(err);
          button.disabled = false;
        }
      }),
  );
  modal.querySelectorAll("[data-end]").forEach(
    (button) =>
      (button.onclick = () =>
        confirmAction(
          "End assignment",
          "This ends the selected assignment and may make passenger verification unavailable.",
          async () => {
            await api(`vehicles/${id}/${button.dataset.end}`, {});
          },
        )),
  );
  modal.querySelector("#revoke").onclick = () =>
    confirmAction(
      "Revoke vehicle QR",
      "The current QR will immediately become unavailable to passengers.",
      async () => {
        await api(`vehicles/${id}/qr/revoke`, {});
      },
    );
  modal.querySelector("#qr-form").onsubmit = async (event) => {
    event.preventDefault();
    const form = event.currentTarget;
    form.querySelector("button").disabled = true;
    try {
      const qr = await api(`vehicles/${id}/qr`, {
        expiresInDays: Number(new FormData(form).get("expiresInDays")),
      });
      showQr(vehicle, qr);
    } catch (err) {
      error(err);
      form.querySelector("button").disabled = false;
    }
  };
}
function showQr(vehicle, qr) {
  dialog(
    "Vehicle verification QR",
    `<div class="qr-print"><p class="eyebrow">ROUTEMATE · VEHICLE REGISTRY</p><h2>${esc(vehicle.plateNumber)}</h2><img id="qr-image" width="280" height="280" alt="Vehicle verification QR code"><p>Scan using the RouteMate passenger page</p><p class="muted">Valid until ${esc(new Date(qr.expiresAt).toLocaleString())}</p><p class="token">${esc(qr.token)}</p></div><p>Download or print now. The code cannot be retrieved again.</p><div class="button-row"><a id="download-qr" class="secondary" download="routemate-vehicle-qr.svg">Download QR</a><button id="print-qr" class="primary">Print</button><a id="check-qr" class="text-link" target="_blank" rel="noopener">Check result ↗</a></div>`,
  );
  qrUrl = URL.createObjectURL(new Blob([qr.svg], { type: "image/svg+xml" }));
  modal.querySelector("#qr-image").src = qrUrl;
  modal.querySelector("#download-qr").href = qrUrl;
  modal.querySelector("#check-qr").href =
    `/verify#${encodeURIComponent(qr.token)}`;
  modal.querySelector("#print-qr").onclick = () => window.print();
}
function stopCamera() {
  scanning = false;
  stream?.getTracks().forEach((track) => track.stop());
  stream = null;
  const video = document.querySelector("video");
  if (video) {
    video.srcObject = null;
    video.hidden = true;
  }
}
function passenger() {
  app.innerHTML = `<div class="passenger"><header>${brand()}<a href="/">Staff sign in ↗</a></header><main id="main"><p class="eyebrow">BEFORE YOU BOARD</p><h1>Check your vehicle.</h1><p class="intro">Scan the RouteMate code displayed on the vehicle to check its registration and current assignments.</p><section class="scan-card"><div class="scan-icon" aria-hidden="true">▦</div><h2>Scan a vehicle QR</h2><p class="muted">Camera access is only used while scanning.</p><video playsinline muted hidden aria-label="QR scanner camera"></video><div class="button-row"><button class="primary" id="scan">Open camera</button><button class="secondary" id="stop">Stop camera</button></div><p id="camera-message" role="status"></p><details><summary>Enter the verification code instead</summary><form id="verify-form"><label>43-character vehicle code<input name="token" required minlength="43" maxlength="43" pattern="[A-Za-z0-9_-]{43}" autocomplete="off" spellcheck="false"></label><button class="secondary">Check vehicle</button></form></details></section><section id="result" aria-live="polite"></section><p class="scope-note">This check confirms registry entries and assignments. It does not certify roadworthiness or guarantee safety. Driver contact details are never displayed.</p></main><footer>RouteMate · Connected transport</footer></div>`;
  const verify = async (token) => {
    stopCamera();
    const result = document.querySelector("#result");
    result.innerHTML = "<p>Checking the registry…</p>";
    try {
      if (!/^[A-Za-z0-9_-]{43}$/.test(token))
        throw new Error("This is not a RouteMate vehicle code");
      const data = await api("public/verify", { token });
      result.innerHTML =
        data.status === "REGISTERED"
          ? `<div class="verification-result"><p class="eyebrow">REGISTRY MATCH FOUND</p><h2>${esc(data.vehicle.plateNumber)}</h2>${badge(data.status)}<p>${esc(data.organization)}</p><dl><dt>Vehicle</dt><dd>${esc([data.vehicle.make, data.vehicle.model, data.vehicle.colour].filter(Boolean).join(" · ") || "Not supplied")}</dd><dt>Vehicle compliance</dt><dd>${badge(data.vehicle.complianceStatus)}</dd><dt>Driver registration</dt><dd>${badge(data.driver.registrationStatus)}</dd><dt>Driver compliance</dt><dd>${badge(data.driver.complianceStatus)}</dd></dl><h3>Authorized routes</h3><ul>${data.routes.map((route) => `<li><strong>${esc(route.name)}</strong><br>${esc(route.origin)} → ${esc(route.destination)}</li>`).join("")}</ul><p class="muted">These are authorized routes, not a live journey location.</p></div>`
          : '<div class="verification-result unavailable"><h2>Verification unavailable</h2><p>This code could not confirm a current registration and assignment. Ask park staff for assistance before relying on it.</p></div>';
    } catch (error) {
      result.innerHTML = `<div class="verification-result unavailable"><h2>Could not check this vehicle</h2><p>${esc(error.message)}</p><p>Please retry when the service is available.</p></div>`;
    }
  };
  document.querySelector("#verify-form").onsubmit = (event) => {
    event.preventDefault();
    verify(new FormData(event.currentTarget).get("token").trim());
  };
  document.querySelector("#stop").onclick = stopCamera;
  document.querySelector("#scan").onclick = async () => {
    const message = document.querySelector("#camera-message");
    try {
      stopCamera();
      if (
        !("BarcodeDetector" in window) ||
        !(await BarcodeDetector.getSupportedFormats()).includes("qr_code")
      )
        throw new Error(
          "Camera scanning is unavailable in this browser. Enter the printed code below, or use a browser with QR scanning support.",
        );
      const detector = new BarcodeDetector({ formats: ["qr_code"] });
      stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: { ideal: "environment" } },
        audio: false,
      });
      const video = document.querySelector("video");
      video.srcObject = stream;
      video.hidden = false;
      await video.play();
      scanning = true;
      message.textContent = "Point the camera at the vehicle QR.";
      const tick = async () => {
        if (!scanning) return;
        try {
          const codes = await detector.detect(video);
          if (codes.length) {
            message.textContent = "Code captured.";
            await verify(codes[0].rawValue);
            return;
          }
        } catch {
          stopCamera();
          message.textContent =
            "Camera scanning stopped. Enter the code below.";
          return;
        }
        if (scanning) setTimeout(tick, 250);
      };
      tick();
    } catch (error) {
      stopCamera();
      message.textContent =
        error.name === "NotAllowedError"
          ? "Camera permission was declined. You can enter the code below."
          : error.message;
      document.querySelector("details").open = true;
    }
  };
  if (location.hash) {
    const token = location.hash.slice(1);
    history.replaceState(null, "", "/verify");
    verify(token);
  }
}
window.addEventListener("pagehide", stopCamera);
document.addEventListener("visibilitychange", () => {
  if (document.hidden) stopCamera();
});
if (location.pathname === "/verify") passenger();
else load().catch(() => login());
