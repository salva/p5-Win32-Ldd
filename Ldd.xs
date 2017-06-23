#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include "libntldd.h"

static SearchPaths *
sv2SearchPaths(SV *sv) {
    if (SvROK(sv)) {
        AV *av = (AV*)SvRV(sv);
        if (SvTYPE((SV*)av) == SVt_PVAV) {
            SearchPaths *search_paths = malloc(sizeof(*search_paths));
            unsigned int i, j, count = av_len(av) + 1;
            search_paths->path = malloc(count * sizeof(char *));
            for (i = j = 0; i < count; i++) {
                SV **svp = av_fetch(av, i, 0);
                if (svp && SvOK(*svp)) search_paths->path[j++] = strdup(SvPV_nolen(*svp));
            }
            search_paths->count = j;
            return search_paths;
        }
    }
    Perl_croak(aTHX_ "argument is not an AV*, unable to convert to SearchPath type");
}

void FreeInsideDepTreeElement(struct DepTreeElement *dte) {
}

void FreeDepTreeElement(struct DepTreeElement *dte) {
    FreeInsideDepTreeElement(dte);
    free(dte);
}

static struct DepTreeElement *
build_dep_tree(char *pe_file,
               SearchPaths *search_paths,
               int datarelocs, int functionrelocs) {
    warn("build_dep_tree(%s, %p, %d, %d)", pe_file, search_paths, datarelocs, functionrelocs);
    struct DepTreeElement root;
    memset(&root, 0, sizeof(root));
    struct DepTreeElement *child = malloc(sizeof(*child));
    memset(child, 0, sizeof(child));
    child->module = strdup(pe_file);
    warn("calling AddDep");
    AddDep(&root, child);

    char **stack;
    uint64_t stack_len = 0;
    uint64_t stack_size = 0;
    BuildTreeConfig cfg;

    memset(&cfg, 0, sizeof(cfg));
    cfg.machineType = -1;
    cfg.on_self = 0;
    cfg.datarelocs = datarelocs;
    cfg.functionrelocs = functionrelocs;
    cfg.stack = &stack;
    cfg.stack_len = &stack_len;
    cfg.stack_size = &stack_size;
    cfg.searchPaths = search_paths;

    warn("calling BuildDepTree");
    int error =  BuildDepTree(&cfg, pe_file, &root, child);

    int i;
    //for (i = 0; i < stack_len; i++) free(stack[i]);
    //free(stack);

    if (error) {
        //FreeInsideDepTreeElement(&root);
        //FreeDepTreeElement(child);
        return NULL;
    }
    return child;
}

static SV *DepTreeElement2sv(struct DepTreeElement *dte);

static SV*
childs2sv(struct DepTreeElement **childs, uint64_t childs_len) {

    AV *av = newAV();
    SV *sv = sv_2mortal(newRV_noinc((SV*)av));

    int i;
    for (i = 0; i < childs_len; i++)
        av_push(av, DepTreeElement2sv(childs[i]));

    return sv;
}

static SV *
exports2sv(struct ExportTableItem *exports, uint64_t exports_len) {
    return &PL_sv_undef;
}

static SV *
imports2sv(struct ImportTableItem *imports, uint64_t imports_len) {
    return &PL_sv_undef;
}

static SV *
DepTreeElement2sv(struct DepTreeElement *dte) {
    HV *hv = newHV();
    SV *sv = sv_2mortal(newRV_noinc((SV*)hv));

    hv_stores(hv, "flags", newSVuv(dte->flags));
    hv_stores(hv, "module", newSVpv(dte->module, 0));
    hv_stores(hv, "export_module", newSVpv(dte->export_module, 0));
    hv_stores(hv, "resolved_module", newSVpv(dte->resolved_module, 0));
    hv_stores(hv, "children", SvREFCNT_inc(childs2sv(dte->childs, dte->childs_len)));
    hv_stores(hv, "imports", SvREFCNT_inc(imports2sv(dte->imports, dte->imports_len)));
    hv_stores(hv, "exports", SvREFCNT_inc(exports2sv(dte->exports, dte->exports_len)));

    return sv;
}

MODULE = Win32::Ldd		PACKAGE = Win32::Ldd

SV *
_build_dep_tree(char *pe_file, SearchPaths *search_paths, int datarelocs, int functionrelocs)
PREINIT:
    struct DepTreeElement *deps;
CODE:
    dTARG;
    warn("calling build_dep_tree");
    deps = build_dep_tree(pe_file, search_paths, datarelocs, functionrelocs);
    warn("build_dep_tree is back: %p", deps);
    if (deps == NULL) {
        Perl_croak(aTHX_ "BuildDepTree failed");
    }
    RETVAL = DepTreeElement2sv(deps);
OUTPUT:
    RETVAL

