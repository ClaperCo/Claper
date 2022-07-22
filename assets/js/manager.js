import { tns } from "tiny-slider"

export class Manager {

  constructor(context) {
    this.context = context
    this.currentPage = parseInt(context.el.dataset.currentPage)
    this.maxPage = parseInt(context.el.dataset.maxPage)
  }

  init() {

    this.context.handleEvent('page-manage', data => {
      var el = document.getElementById("slide-preview-" + data.current_page)

      if (el) {
        setTimeout(() => {
          document.getElementById("slide-preview-" + data.current_page).scrollIntoView({
            block: 'center',
            behavior: 'smooth'
          });  
        }, data.timeout ? data.timeout : 0)
      }
    })

    window.addEventListener('keydown', (e) => {
      
      if (e.target.tagName.toLowerCase() != "input") {
        e.preventDefault()

        switch (e.key) {
          case 'ArrowUp':
            this.prevPage()
            break
          case 'ArrowLeft':
            this.prevPage()
            break
          case 'ArrowRight':
            this.nextPage()
            break
          case 'ArrowDown':
            this.nextPage()
            break
        }  
      }
    });
  }

  update() {
    this.currentPage = parseInt(this.context.el.dataset.currentPage)
    var el = document.getElementById("slide-preview-" + this.currentPage)

    if (el) {
      document.getElementById("slide-preview-" + this.currentPage).scrollIntoView({
        block: 'center',
        behavior: 'smooth'
      });  
    }
  }

  nextPage() {
    if(this.currentPage == this.maxPage - 1) 
      return;    
 
    this.currentPage += 1;
    this.context.pushEventTo(this.context.el, "current-page", {"page": this.currentPage.toString()});
  }
  
  prevPage() {
    if(this.currentPage == 0) 
      return;
      
    this.currentPage -= 1;
    this.context.pushEventTo(this.context.el, "current-page", {"page": this.currentPage.toString()});

  }
  
}