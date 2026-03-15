# ⚡ SFDX Portfolio Site

A public-facing portfolio hub built entirely on Salesforce Experience Cloud — showcasing Salesforce projects, demos, and source code. Visitors can browse projects, filter by category and tags, watch demos, and jump straight to GitHub repositories.

**The twist?** This site is its own first showcase project. The very platform you're browsing is Project #1 in the gallery — a self-referential demonstration of the builder's skills in Salesforce Experience Cloud, LWC, Apex, and SFDX.

> Inspired by [platformdemos.com](https://platformdemos.com) — reimagined as a personal portfolio and project catalog.

---

## 🧰 Tech Stack

| Layer | Technology |
|-------|-----------|
| **Platform** | Salesforce Experience Cloud (LWR "Build Your Own" template) |
| **Frontend** | Lightning Web Components (LWC) |
| **Backend** | Apex Controllers |
| **Data Model** | Custom Objects (Project, Tag, Project Tag, Project Asset) |
| **Deployment** | SFDX Source Format, `sf` CLI |
| **Version Control** | Git + GitHub |
| **CI/CD** | GitHub Actions *(planned)* |
| **Access** | Public site via Guest User (read-only, no login required) |

---

## 🏗️ Architecture

### How It Works

The portfolio site is a **catalog**. Each showcase project lives in its own independent GitHub repository. The site stores metadata about each project (description, category, tags, links) in custom Salesforce objects and renders them through custom LWC components on a publicly accessible Experience Cloud site.

```
┌─────────────────────────────────────────────────┐
│           Experience Cloud (LWR Site)            │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ Project  │  │ Project  │  │   Project     │  │
│  │  Hero    │  │  Filter  │  │   Gallery     │  │
│  └──────────┘  └──────────┘  └───────┬───────┘  │
│                                      │           │
│                              ┌───────▼───────┐   │
│                              │  Project Card │   │
│                              └───────┬───────┘   │
│                                      │           │
│                              ┌───────▼───────┐   │
│                              │Project Detail │   │
│                              └───────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐    │
│  │         Apex: ProjectController          │    │
│  └──────────────────┬───────────────────────┘    │
│                     │                            │
│  ┌──────────────────▼───────────────────────┐    │
│  │  Project__c │ Tag__c │ Project_Tag__c    │    │
│  │              Project_Asset__c             │    │
│  └──────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
         │                          │
         ▼                          ▼
  ┌──────────────┐          ┌──────────────┐
  │  GitHub Repo │          │  GitHub Repo │
  │  (Project A) │          │  (Project B) │
  └──────────────┘          └──────────────┘
```

### Data Model

- **Project\_\_c** — One record per portfolio project. Stores name, description, category, status, links (GitHub, live demo, video, docs), tech stack, difficulty level, and display settings.
- **Tag\_\_c** — Flexible labels for filtering (e.g., "REST API", "Batch Apex", "Guest User").
- **Project\_Tag\_\_c** — Junction object enabling many-to-many relationships between projects and tags.
- **Project\_Asset\_\_c** — Child records for additional resources per project (videos, PDFs, slide decks, blog posts).

### Key Components

| Component | Purpose |
|-----------|---------|
| `projectHero` | Hero banner with tagline, featured project spotlight, and quick stats |
| `projectFilter` | Category chips, tag selection, and search bar for filtering |
| `projectGallery` | Main grid view — queries and renders project cards with pagination |
| `projectCard` | Reusable tile with thumbnail, description, tech badges, and action buttons |
| `projectDetail` | Full detail page with rich description, embedded video, assets, and GitHub link |

---

## 📁 Project Structure

```
sfdx-portfolio-site/
├── force-app/main/default/
│   ├── classes/            # Apex controllers + test classes
│   ├── lwc/                # Lightning Web Components
│   ├── objects/            # Custom object & field definitions
│   ├── permissionsets/     # PortfolioAdmin, PortfolioViewer
│   ├── flexipages/         # Page layouts for Experience Cloud
│   ├── labels/             # Custom labels (user-facing text)
│   ├── tabs/               # Custom tabs
│   └── staticresources/    # Images, icons, etc.
│
├── experience-cloud/       # ExperienceBundle, Network, Site config
├── data/                   # Sample data and import scripts
├── scripts/                # Setup, deployment, and publish scripts
├── docs/                   # Architecture, setup guide, screenshots
├── config/
│   └── project-scratch-def.json
└── sfdx-project.json
```

---

## 🚀 Getting Started

### Prerequisites

- [Salesforce CLI (`sf`)](https://developer.salesforce.com/tools/salesforcecli) installed
- A Salesforce Developer Edition org or Dev Hub for scratch orgs
- Git
- Node.js (for LWC Jest tests)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/sfdx-portfolio-site.git
   cd sfdx-portfolio-site
   ```

2. **Authorize your org**
   ```bash
   sf org login web --alias sfdx-portfolio --set-default
   ```

3. **Deploy the metadata**
   ```bash
   sf project deploy start --source-dir force-app -o sfdx-portfolio
   ```

4. **Import sample data**
   ```bash
   sf data import tree --plan data/data-plan.json -o sfdx-portfolio
   ```

5. **Deploy Experience Cloud configuration**
   ```bash
   sf project deploy start --source-dir experience-cloud -o sfdx-portfolio
   ```

6. **Publish the site** via Experience Builder or:
   ```bash
   sf community publish --name "Portfolio Site" -o sfdx-portfolio
   ```

---

## 🔐 Security Model

This site is publicly accessible — **no login required**. Security is enforced through:

- **Guest User Profile** with strictly read-only access to Project\_\_c, Tag\_\_c, Project\_Tag\_\_c, and Project\_Asset\_\_c.
- **No create, update, or delete** permissions for guest users on any object.
- **`WITH SECURITY_ENFORCED`** in all SOQL queries for field-level security enforcement.
- **`AuraHandledException`** for graceful error handling — no internal details exposed to the client.
- No sensitive data (internal IDs, config secrets, admin fields) exposed to the guest profile.

---

## 🤝 Contributing

Contributions are welcome! Whether it's fixing a bug, improving a component, or submitting a new showcase project, check out [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Adding a New Showcase Project

1. Build your project in its own GitHub repository following the [showcase project template](docs/adding-a-new-project.md).
2. Ensure it has a working README, scratch org setup, and sample data.
3. Create a `Project__c` record in the portfolio org with links to your repo, demo, and docs.
4. Your project appears on the site automatically.

---

## 📋 Roadmap

- [x] Initialize SFDX project and repository
- [ ] Create custom objects and fields
- [ ] Build Apex controller with test class
- [ ] Build LWC components (Hero, Filter, Gallery, Card, Detail)
- [ ] Configure Experience Cloud site (LWR template, pages, theme)
- [ ] Set up Guest User permissions
- [ ] Create sample data with self-referencing project entry
- [ ] Deploy and publish site
- [ ] Set up GitHub Actions CI/CD
- [ ] Build first external showcase project
- [ ] Add additional showcase projects across Salesforce capabilities

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

---

## 📬 Contact

Have questions, feedback, or want to collaborate? Open an [issue](https://github.com/YOUR_USERNAME/sfdx-portfolio-site/issues) or reach out directly.

---

*Built with ❤️ on Salesforce*