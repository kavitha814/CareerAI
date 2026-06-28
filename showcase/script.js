document.addEventListener('DOMContentLoaded', () => {
  
  // ───── MOBILE MENU TRIGGER ─────
  const hamburger = document.getElementById('hamburger');
  const navbar = document.getElementById('navbar');
  const mobileMenuLinks = document.querySelectorAll('#mobileMenu a');

  if (hamburger && navbar) {
    hamburger.addEventListener('click', () => {
      navbar.classList.toggle('open');
    });

    mobileMenuLinks.forEach(link => {
      link.addEventListener('click', () => {
        navbar.classList.remove('open');
      });
    });
  }

  // ───── SCROLL EFFECT ON NAVBAR ─────
  window.addEventListener('scroll', () => {
    if (window.scrollY > 50) {
      navbar.classList.add('scrolled');
    } else {
      navbar.classList.remove('scrolled');
    }
  });

  // ───── SCREEN GALLERY SWITCHER ─────
  const tabs = document.querySelectorAll('.gtab');
  const slides = document.querySelectorAll('.gslide');

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      // Remove active class from all tabs & slides
      tabs.forEach(t => t.classList.remove('active'));
      slides.forEach(s => s.classList.remove('active'));

      // Add active to current tab
      tab.classList.add('active');

      // Get target slide and activate
      const targetId = `slide-${tab.dataset.target}`;
      const targetSlide = document.getElementById(targetId);
      if (targetSlide) {
        targetSlide.classList.add('active');
      }
    });
  });

  // ───── INTERACTIVE COACH SANDBOX ─────
  const sandboxQuestions = [
    {
      question: "What career path do you want to master?",
      options: [
        { label: "Flutter Developer", icon: "📱", value: "Flutter" },
        { label: "SolidWorks Designer", icon: "📐", value: "SolidWorks" },
        { label: "DevOps Specialist", icon: "⚡", value: "DevOps" },
        { label: "Data Analyst", icon: "📊", value: "Data" }
      ]
    },
    {
      question: "What is your current experience level?",
      options: [
        { label: "Beginner (No background)", icon: "🌱", value: "Beginner" },
        { label: "Intermediate (Know core concepts)", icon: "🌿", value: "Intermediate" },
        { label: "Advanced (Looking to scale & optimize)", icon: "🌳", value: "Advanced" }
      ]
    },
    {
      question: "What is your weekly study commitment?",
      options: [
        { label: "1-2 hours/day (Slow & steady)", icon: "⏳", value: "Part-time" },
        { label: "3-4 hours/day (Balanced pace)", icon: "📅", value: "Balanced" },
        { label: "Full-time (Intensive deep dive)", icon: "🚀", value: "Full-time" }
      ]
    }
  ];

  let currentStep = 0;
  let selectedOptionIndex = null;
  const userAnswers = [];

  const questionnaireCard = document.getElementById('questionnaireCard');
  const stepIndicator = document.getElementById('stepIndicator');
  const stepProgressBar = document.getElementById('stepProgressBar');
  let sandboxQuestionText = document.getElementById('sandboxQuestion');
  let sandboxOptionsContainer = document.getElementById('sandboxOptions');
  const sandboxNextBtn = document.getElementById('sandboxNextBtn');
  
  const resultsCard = document.getElementById('resultsCard');
  const resultsTitle = document.getElementById('resultsTitle');
  const resultsDesc = document.getElementById('resultsDesc');
  const resultsTimeline = document.getElementById('resultsTimeline');
  const restartSandboxBtn = document.getElementById('restartSandboxBtn');

  function renderQuestion() {
    if (!sandboxQuestionText || !sandboxOptionsContainer) return;
    
    const currentQ = sandboxQuestions[currentStep];
    
    // Update header
    stepIndicator.textContent = `Question ${currentStep + 1} of ${sandboxQuestions.length}`;
    stepProgressBar.style.width = `${((currentStep + 1) / sandboxQuestions.length) * 100}%`;
    
    // Update question
    sandboxQuestionText.textContent = currentQ.question;
    
    // Render options
    sandboxOptionsContainer.innerHTML = '';
    selectedOptionIndex = null;
    sandboxNextBtn.classList.add('btn-disabled');
    sandboxNextBtn.disabled = true;

    currentQ.options.forEach((opt, idx) => {
      const optionEl = document.createElement('div');
      optionEl.className = 'sandbox-opt';
      optionEl.innerHTML = `
        <span style="display:flex; align-items:center; gap:12px;">
          <span style="font-size:18px;">${opt.icon}</span>
          <span>${opt.label}</span>
        </span>
        <span class="sandbox-radio-dot"></span>
      `;
      
      optionEl.addEventListener('click', () => {
        // Remove previous selection
        const prevSelected = sandboxOptionsContainer.querySelector('.selected');
        if (prevSelected) prevSelected.classList.remove('selected');
        
        // Select current
        optionEl.classList.add('selected');
        selectedOptionIndex = idx;
        
        // Enable next button
        sandboxNextBtn.classList.remove('btn-disabled');
        sandboxNextBtn.disabled = false;
      });
      
      sandboxOptionsContainer.appendChild(optionEl);
    });
  }

  // Initial render
  renderQuestion();

  if (sandboxNextBtn) {
    sandboxNextBtn.addEventListener('click', () => {
      if (selectedOptionIndex === null) return;
      
      const currentQ = sandboxQuestions[currentStep];
      userAnswers.push(currentQ.options[selectedOptionIndex].value);
      
      currentStep++;
      
      if (currentStep < sandboxQuestions.length) {
        renderQuestion();
      } else {
        showLoadingState();
      }
    });
  }

  function showLoadingState() {
    // Hide standard question card content
    const top = questionnaireCard.querySelector('.sandbox-top');
    const qText = questionnaireCard.querySelector('#sandboxQuestion');
    const opts = questionnaireCard.querySelector('#sandboxOptions');
    const foot = questionnaireCard.querySelector('.sandbox-foot');
    
    if (top) top.classList.add('hidden');
    if (qText) qText.classList.add('hidden');
    if (opts) opts.classList.add('hidden');
    if (foot) foot.classList.add('hidden');
    
    // Create or show loading container
    let loadingDiv = questionnaireCard.querySelector('.sandbox-loading');
    if (!loadingDiv) {
      loadingDiv = document.createElement('div');
      loadingDiv.className = 'sandbox-loading';
      questionnaireCard.appendChild(loadingDiv);
    }
    
    loadingDiv.innerHTML = `
      <div class="spinner"></div>
      <h3 style="font-family:var(--font-title); font-size:18px; margin-top: 16px; margin-bottom: 8px;">Analyzing skills and career parameters...</h3>
      <p style="color:var(--muted); font-size:13.5px; text-align:center;">
        AI is compiling customized learning tracks and video tutorial search filters...
      </p>
    `;
    loadingDiv.classList.remove('hidden');

    // Wait 1.5 seconds to mock live API call, then render roadmap results
    setTimeout(() => {
      questionnaireCard.classList.add('hidden');
      generateAndShowRoadmap();
    }, 1600);
  }

  function generateAndShowRoadmap() {
    const career = userAnswers[0];
    const experience = userAnswers[1];
    const pacing = userAnswers[2];

    resultsTitle.textContent = `${experience} ${career} Learning Pathway`;
    resultsDesc.textContent = `A customized 4-Week learning curriculum optimized for a ${experience} looking for a ${pacing} pace. Checklists include context-aware search queries linking directly to YouTube tutorials.`;

    resultsTimeline.innerHTML = '';

    const milestoneTemplates = {
      Flutter: [
        {
          title: "Introduction to Dart Fundamentals",
          desc: "Master OOP principles, variables, collections, asynchronous programming (Futures/Streams) and null safety.",
          tasks: ["OOP Basics", "Dart Collections", "Async Dart"]
        },
        {
          title: "UI Rendering & Widget Tree Layouts",
          desc: "Learn Scaffold layout grids, custom constraints, responsive widget configurations, and asset loaders.",
          tasks: ["Stateless/Stateful Widgets", "Flex & Columns Layouts", "Responsive MediaQueries"]
        },
        {
          title: "State Management Architectures",
          desc: "Understand app state scopes, provider structures, and data caching using local databases like Hive.",
          tasks: ["Riverpod state providers", "Hive key-value setup", "JSON Parsing"]
        },
        {
          title: "Animations & Google Store Deployments",
          desc: "Create smooth transitions, use custom painters, build release binaries, and upload to Google Play Console.",
          tasks: ["Custom Transition Animations", "Flutter Build APK", "Console Listing setup"]
        }
      ],
      SolidWorks: [
        {
          title: "Interface Navigation & Sketching",
          desc: "Master workspace navigation, orthographic grid layouts, constraint relations, and basic 2D sketching tools.",
          tasks: ["Workspace coordinates", "2D sketch geometric constraints", "Extrude Base Boss"]
        },
        {
          title: "Solid Part Design & Modeling",
          desc: "Build basic 3D parts, apply fillets/chamfers, cut hollow spaces, and create custom plane offsets.",
          tasks: ["Revolved Boss/Base", "Extruded Cut", "Reference geometry planes"]
        },
        {
          title: "Assemblies & Mates Configuration",
          desc: "Combine individual parts inside an assembly structure, configure concentric/coincident mechanical mates.",
          tasks: ["Part import templates", "Coincident & concentric mates", "Exploded assembly views"]
        },
        {
          title: "Engineering Drawings & Simulation",
          desc: "Export models to standard detailed engineering projection sheets and run stress/deflection analysis.",
          tasks: ["Drawing sheet projections", "Dimensioning layouts", "FEA stress simulation reports"]
        }
      ],
      DevOps: [
        {
          title: "Linux CLI & Scripting Automation",
          desc: "Understand bash command operations, user security access rules, environment variables, and shell scripting.",
          tasks: ["File permissions chmod/chown", "Bash loop scripts", "SSH credential keys"]
        },
        {
          title: "Containerization with Docker",
          desc: "Write lightweight Dockerfiles, build local custom image layers, and coordinate multi-containers with Compose.",
          tasks: ["Write Dockerfile structures", "Docker Compose volumes", "Container networking"]
        },
        {
          title: "CI/CD Automations & Git Workflows",
          desc: "Write GitHub Actions workflow definitions to compile, test, and package applications automatically on code push.",
          tasks: ["Git branching scopes", "GitHub Actions runner yaml", "Unit test integration"]
        },
        {
          title: "Infrastructure as Code & Cloud Deployments",
          desc: "Define server resources dynamically using Terraform scripts, and launch environments inside AWS or Google Cloud.",
          tasks: ["Terraform HCL scripts", "Serverless cloud instances", "Nginx reverse proxy setup"]
        }
      ],
      Data: [
        {
          title: "SQL Queries & Database Retrievals",
          desc: "Master relational schemas, write nested select queries, perform multi-table Joins, and audit database indexes.",
          tasks: ["Select aggregates & filters", "Inner & Left Joins", "Group By operations"]
        },
        {
          title: "Python Data Wrangling (Pandas)",
          desc: "Load datasets from CSV/JSON, clean missing inputs, handle null fields, and manipulate DataFrames.",
          tasks: ["Pandas DataFrame loading", "Null values drop/fill", "Groupby aggregates"]
        },
        {
          title: "Data Visualization (Seaborn & Tableau)",
          desc: "Design detailed line charts, scatter correlation plots, box plots, and compile interactive dashboard sheets.",
          tasks: ["Matplotlib plotting parameters", "Dashboard grid setup", "Tableau filters"]
        },
        {
          title: "Probability & Basic Machine Learning",
          desc: "Evaluate correlations, calculate standard deviations, run linear regression, and model predictions.",
          tasks: ["Normal distribution calculations", "Linear regression slopes", "Model validation metrics"]
        }
      ]
    };

    const milestones = milestoneTemplates[career] || milestoneTemplates.Flutter;

    milestones.forEach((m, idx) => {
      const milestoneEl = document.createElement('div');
      milestoneEl.className = 'milestone-item';
      
      // Build tasks HTML with smart YouTube search links
      let tasksHtml = '';
      m.tasks.forEach(t => {
        const query = `${t} in ${m.title} ${career} tutorial ${experience.toLowerCase()}`;
        const encodedQuery = encodeURIComponent(query);
        const youtubeUrl = `https://www.youtube.com/results?search_query=${encodedQuery}`;
        
        tasksHtml += `
          <a href="${youtubeUrl}" target="_blank" class="sandbox-task-link" style="text-decoration:none;">
            <span style="font-size:11px; background-color:rgba(59, 130, 246, 0.08); border:1px solid rgba(59, 130, 246, 0.2); color:var(--blue); padding:4px 8px; border-radius:6px; font-weight:600; display:inline-flex; align-items:center; gap:4px; cursor:pointer;">
              📺 ${t}
            </span>
          </a>
        `;
      });

      milestoneEl.innerHTML = `
        <span class="milestone-week">Week ${idx + 1}</span>
        <div class="milestone-info" style="flex-grow: 1;">
          <h4 class="milestone-title" style="margin-bottom: 4px;">${m.title}</h4>
          <p class="milestone-sub">${m.desc}</p>
          <div class="sandbox-milestone-tasks" style="display:flex; flex-wrap:wrap; gap:6px; margin-top:8px;">
            ${tasksHtml}
          </div>
        </div>
      `;
      resultsTimeline.appendChild(milestoneEl);
    });

    resultsCard.classList.remove('hidden');
  }

  if (restartSandboxBtn) {
    restartSandboxBtn.addEventListener('click', () => {
      currentStep = 0;
      selectedOptionIndex = null;
      userAnswers.length = 0;
      
      resultsCard.classList.add('hidden');
      
      // Restore questionnaire elements
      const top = questionnaireCard.querySelector('.sandbox-top');
      const qText = questionnaireCard.querySelector('#sandboxQuestion');
      const opts = questionnaireCard.querySelector('#sandboxOptions');
      const foot = questionnaireCard.querySelector('.sandbox-foot');
      const loadingDiv = questionnaireCard.querySelector('.sandbox-loading');
      
      if (top) top.classList.remove('hidden');
      if (qText) qText.classList.remove('hidden');
      if (opts) opts.classList.remove('hidden');
      if (foot) foot.classList.remove('hidden');
      if (loadingDiv) loadingDiv.classList.add('hidden');
      
      questionnaireCard.classList.remove('hidden');
      
      // Re-run initial render
      renderQuestion();
    });
  }

});
