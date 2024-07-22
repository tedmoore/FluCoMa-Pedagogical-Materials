(
fork{
	d = FluidDataSet(s).read("/Users/ted/Documents/_TEACHING/_materials/flucoma/FluCoMa-Pedagogical-Materials-repo/max/01c-validate-ds.json");
	l = FluidLabelSet(s).read("/Users/ted/Documents/_TEACHING/_materials/flucoma/FluCoMa-Pedagogical-Materials-repo/max/01c-validate-ls.json");
	s.sync;
	d.postln;
	l.postln;
	s.sync;
	PlotXYColor.fromFluidDataSet(d,l,slewTime:0);
}
)