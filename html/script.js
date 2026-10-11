const { createApp } = Vue;

const RING_HUD = 106.81;
const RING_BIG = 326.73;

const resourceName = () => (window.GetParentResourceName ? GetParentResourceName() : 'OwnCrafting');

createApp({
    data() {
        return {
            visible: false,
            view: 'home',
            texts: {},
            config: {
                iconPath: '',
                fallbackIcon: 'unknown.png',
                maxQueue: 5,
                maxAmount: 100,
                showLocked: true,
                accent: '#00a2ff',
                danger: '#ff4d6d',
            },
            bench: { label: '', description: '' },
            recipes: [],
            inventory: [],
            queue: [],
            search: '',
            selected: null,
            amount: 1,
            crafting: false,
            sparkKey: 0,
            hud: { state: 'hidden', label: '', icon: '', count: 1, more: 0, progress: 0 },
            hudTimer: null,
        };
    },

    computed: {
        availableRecipes() {
            return this.recipes.filter(r => !r.locked);
        },

        filteredRecipes() {
            const q = this.search.trim().toLowerCase();
            if (!q) return this.recipes;
            return this.recipes.filter(r =>
                r.label.toLowerCase().includes(q) || r.name.toLowerCase().includes(q)
            );
        },

        maxAmount() {
            if (!this.selected) return 0;
            let max = this.config.maxAmount;
            for (const input of this.selected.inputs) {
                max = Math.min(max, Math.floor(this.countOf(input.item) / input.amount));
            }
            return Math.max(0, max);
        },

        queueFull() {
            return this.queue.length >= this.config.maxQueue;
        },

        canCraft() {
            return !!this.selected
                && !this.selected.locked
                && this.maxAmount > 0
                && !this.queueFull;
        },

        craftLabel() {
            if (!this.selected) return this.t('ui_craft');
            if (this.selected.locked) return this.t('ui_locked');
            if (this.queueFull) return this.t('ui_queue_full');
            if (this.maxAmount <= 0) return this.t('ui_missing');
            return this.t('ui_craft');
        },

        tabs() {
            return [
                { id: 'home', label: this.t('ui_tab_home'), icon: 'fas fa-house' },
                { id: 'craft', label: this.t('ui_tab_recipes'), icon: 'fas fa-book' },
                { id: 'queue', label: this.t('ui_tab_queue'), icon: 'fas fa-list-check', badge: this.queue.length || '' },
            ];
        },

        progressPct() {
            return Math.round(this.hud.progress * 100) + '%';
        },

        remainingMs() {
            const job = this.queue[0];
            return job ? job.duration * (1 - this.hud.progress) : 0;
        },

        freeSlotsText() {
            const free = Math.max(0, this.config.maxQueue - this.queue.length);
            return this.t('ui_queue_free').replace('%d', free);
        },

        hudRingOffset() {
            const p = this.hud.state === 'cancelled' ? 1 : this.hud.progress;
            return RING_HUD * (1 - Math.min(1, Math.max(0, p)));
        },

        moreText() {
            return this.t('ui_hud_more').replace('%d', this.hud.more);
        },
    },

    watch: {
        maxAmount() {
            this.clampAmount();
        },
    },

    methods: {
        t(key) {
            return this.texts[key] || key;
        },

        ringOffset(progress) {
            return RING_BIG * (1 - Math.min(1, Math.max(0, progress)));
        },

        iconUrl(name) {
            return `${this.config.iconPath}${name}.png`;
        },

        onIconError(event) {
            const img = event.target;
            if (img.dataset.fallback) return;
            img.dataset.fallback = '1';
            img.src = `${this.config.iconPath}${this.config.fallbackIcon}`;
        },

        countOf(name) {
            const item = this.inventory.find(i => i.name === name);
            return item ? item.count : 0;
        },

        itemLabel(name) {
            const item = this.inventory.find(i => i.name === name);
            return item ? item.label : name;
        },

        matPct(input) {
            const need = input.amount * this.amount;
            return Math.min(100, Math.round((this.countOf(input.item) / need) * 100)) + '%';
        },

        sparkStyle(n) {
            return {
                '--r': `${n * 30}deg`,
                animationDelay: `${(n % 3) * 40}ms`,
            };
        },

        formatTime(ms) {
            const totalSeconds = Math.round(ms / 1000);
            if (totalSeconds < 60) return `${totalSeconds}s`;
            const minutes = Math.floor(totalSeconds / 60);
            const seconds = totalSeconds % 60;
            return seconds ? `${minutes}m ${seconds}s` : `${minutes}m`;
        },

        selectRecipe(recipe) {
            this.selected = recipe;
            this.amount = 1;
        },

        changeAmount(delta) {
            const limit = Math.max(1, this.maxAmount);
            const next = (Number(this.amount) || 1) + delta;
            this.amount = Math.min(Math.max(1, next), limit);
        },

        clampAmount() {
            const limit = Math.max(1, this.maxAmount);
            const value = Math.floor(Number(this.amount)) || 1;
            this.amount = Math.min(Math.max(1, value), limit);
        },

        setMax() {
            this.amount = Math.max(1, this.maxAmount);
        },

        startCraft() {
            if (!this.canCraft) return;
            this.crafting = true;
            this.sparkKey++;
            setTimeout(() => { this.crafting = false; }, 600);
            this.post('startCraft', { recipe: this.selected.name, count: this.amount });
        },

        cancelQueue() {
            if (!this.queue.length) return;
            this.post('cancelQueue');
        },

        close() {
            if (!this.visible) return;
            this.visible = false;
            this.post('close');
        },

        post(endpoint, data = {}) {
            fetch(`https://${resourceName()}/${endpoint}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data),
            }).catch(() => {});
        },

        open(data) {
            this.texts = data.texts || {};
            this.config = { ...this.config, ...(data.config || {}) };
            document.documentElement.style.setProperty('--accent', this.config.accent);
            document.documentElement.style.setProperty('--danger', this.config.danger);

            this.bench = data.bench || this.bench;
            this.recipes = data.recipes || [];
            this.inventory = data.inventory || [];
            this.queue = Object.values(data.queue || {});
            this.search = '';
            this.selected = null;
            this.amount = 1;
            this.view = 'home';
            this.visible = true;
        },

        updateHud(data) {
            clearTimeout(this.hudTimer);
            if (!data.show) {
                if (this.hud.state === 'active') this.fadeHud();
                return;
            }
            this.hud = {
                ...this.hud,
                state: 'active',
                label: data.label,
                icon: data.icon,
                count: data.count,
                more: data.more,
            };
        },

        fadeHud() {
            this.hud.state = 'fading';
            this.hudTimer = setTimeout(() => {
                this.hud.state = 'hidden';
            }, 500);
        },

        showCancel() {
            clearTimeout(this.hudTimer);
            this.hud.state = 'cancelled';
            this.hud.progress = 1;
            this.hudTimer = setTimeout(() => {
                this.hud.state = 'fading';
                this.hudTimer = setTimeout(() => {
                    this.hud.state = 'hidden';
                }, 500);
            }, 3000);
        },

        onMessage(data) {
            switch (data.action) {
                case 'open':
                    this.open(data);
                    break;
                case 'inventory':
                    this.inventory = data.inventory || [];
                    break;
                case 'queue':
                    this.queue = Object.values(data.jobs || {});
                    break;
                case 'hud':
                    this.updateHud(data);
                    break;
                case 'hudTick':
                    this.hud.progress = data.progress;
                    break;
                case 'hudCancel':
                    this.showCancel();
                    break;
            }
        },
    },

    mounted() {
        window.addEventListener('message', (event) => this.onMessage(event.data));
        window.addEventListener('keydown', (event) => {
            if (event.key === 'Escape') this.close();
        });
    },
}).mount('#app');
