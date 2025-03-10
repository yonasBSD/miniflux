class TouchHandler {
    constructor() {
        this.reset();
    }

    reset() {
        this.touch = {
            start: { x: -1, y: -1 },
            move: { x: -1, y: -1 },
            moved: false,
            time: 0,
            element: null
        };
    }

    calculateDistance() {
        if (this.touch.start.x >= -1 && this.touch.move.x >= -1) {
            const horizontalDistance = Math.abs(this.touch.move.x - this.touch.start.x);
            const verticalDistance = Math.abs(this.touch.move.y - this.touch.start.y);

            if (horizontalDistance > 30 && verticalDistance < 70 || this.touch.moved) {
                return this.touch.move.x - this.touch.start.x;
            }
        }

        return 0;
    }

    static findElement(element) {
        if (element.classList.contains("entry-swipe")) {
            return element;
        }

        return element.closest(".entry-swipe");
    }

    onItemTouchStart(event) {
        if (event.touches === undefined || event.touches.length !== 1) {
            return;
        }

        this.reset();
        this.touch.start.x = event.touches[0].clientX;
        this.touch.start.y = event.touches[0].clientY;
        this.touch.element = TouchHandler.findElement(event.touches[0].target);
        this.touch.element.style.transitionDuration = "0s";
    }

    onItemTouchMove(event) {
        if (event.touches === undefined || event.touches.length !== 1 || this.element === null) {
            return;
        }

        this.touch.move.x = event.touches[0].clientX;
        this.touch.move.y = event.touches[0].clientY;

        const distance = this.calculateDistance();
        const absDistance = Math.abs(distance);

        if (absDistance > 0) {
            this.touch.moved = true;

            const tx = (absDistance > 75 ? Math.sqrt(absDistance - 75) + 75 : absDistance) * Math.sign(distance);

            this.touch.element.style.transform = "translateX(" + tx + "px)";

            event.preventDefault();
        }
    }

    onItemTouchEnd(event) {
        if (event.touches === undefined) {
            return;
        }

        if (this.touch.element !== null) {
            if (Math.abs(this.calculateDistance()) > 75) {
                toggleEntryStatus(this.touch.element);
            }

            if (this.touch.moved) {
                this.touch.element.style.transitionDuration = "0.15s";
                this.touch.element.style.transform = "none";
            }
        }

        this.reset();
    }

    onContentTouchStart(event) {
        if (event.touches === undefined || event.touches.length !== 1) {
            return;
        }

        this.reset();
        this.touch.start.x = event.touches[0].clientX;
        this.touch.start.y = event.touches[0].clientY;
        this.touch.time = Date.now();
    }

    onContentTouchMove(event) {
        if (event.touches === undefined || event.touches.length !== 1 || this.element === null) {
            return;
        }

        this.touch.move.x = event.touches[0].clientX;
        this.touch.move.y = event.touches[0].clientY;
    }

    onContentTouchEnd(event) {
        if (event.touches === undefined) {
            return;
        }

        if (Date.now() - this.touch.time <= 1000) {
            const distance = this.calculateDistance();
            const absDistance = Math.abs(distance);
            if (absDistance > 75) {
                if (distance > 0) {
                    goToPage("previous");
                } else {
                    goToPage("next");
                }
            }
        }

        this.reset();
    }

    onTapEnd(event) {
        if (event.touches === undefined) {
            return;
        }

        const now = Date.now();

        if (this.touch.start.x !== -1 && now - this.touch.time <= 200) {
            const innerWidthHalf = window.innerWidth / 2;

            if (this.touch.start.x >= innerWidthHalf && event.changedTouches[0].clientX >= innerWidthHalf) {
                goToPage("next");
            } else if (this.touch.start.x < innerWidthHalf && event.changedTouches[0].clientX < innerWidthHalf) {
                goToPage("previous");
            }

            this.reset();
        } else {
            this.reset();
            this.touch.start.x = event.changedTouches[0].clientX;
            this.touch.time = now;
        }
    }

    listen() {
        const eventListenerOptions = { passive: true };

        document.querySelectorAll(".entry-swipe").forEach((element) => {
            element.addEventListener("touchstart", (e) => this.onItemTouchStart(e), eventListenerOptions);
            element.addEventListener("touchmove", (e) => this.onItemTouchMove(e));
            element.addEventListener("touchend", (e) => this.onItemTouchEnd(e), eventListenerOptions);
            element.addEventListener("touchcancel", () => this.reset(), eventListenerOptions);
        });

        const element = document.querySelector(".entry-content");
        if (element) {
            if (element.classList.contains("gesture-nav-tap")) {
                element.addEventListener("touchend", (e) => this.onTapEnd(e), eventListenerOptions);
                element.addEventListener("touchmove", () => this.reset(), eventListenerOptions);
                element.addEventListener("touchcancel", () => this.reset(), eventListenerOptions);
            } else if (element.classList.contains("gesture-nav-swipe")) {
                element.addEventListener("touchstart", (e) => this.onContentTouchStart(e), eventListenerOptions);
                element.addEventListener("touchmove", (e) => this.onContentTouchMove(e), eventListenerOptions);
                element.addEventListener("touchend", (e) => this.onContentTouchEnd(e), eventListenerOptions);
                element.addEventListener("touchcancel", () => this.reset(), eventListenerOptions);
            }
        }
    }
}
