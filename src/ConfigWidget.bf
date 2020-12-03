using Beefy.widgets;
using Beefy.gfx;
using Beefy.theme.dark;
using System;

namespace iBuddy
{
	class ConfigWidget : Widget
	{
		public DarkComboBox mRecordLapCombo;
		public DarkCheckBox mRecordDataCheckbox;
		
		public this()
		{
			mRecordLapCombo = new DarkComboBox();
			AddWidget(mRecordLapCombo);
			mRecordLapCombo.mPopulateMenuAction.Add(new (menu) =>
				{
					void AddItem(StringView label)
					{
						var item = menu.AddItem(label);
						item.mOnMenuItemSelected.Add(new (menu) =>
							{
								mRecordLapCombo.Label = menu.mLabel;
							});
					}

					AddItem("Disabled");
					AddItem("Record");
					AddItem("Compare");
				});
			mRecordLapCombo.Label = "Disabled";

			mRecordDataCheckbox = new .();
			mRecordDataCheckbox.Label = "Record Data";
			//mRecordDataCheckbox.Checked = true;
			AddWidget(mRecordDataCheckbox);

			ResizeComponents();
		}

		void ResizeComponents()
		{
			mRecordLapCombo.Resize(8, 30, 200, 20);
			mRecordDataCheckbox.Resize(8, 54, 200, 24);
		}

		public override void Update()
		{
			base.Update();
			//ResizeComponents();
		}

		public override void Draw(Graphics g)
		{
			base.Draw(g);

			using (g.PushColor(0xFF000020))
				g.FillRect(0, 0, mWidth, mHeight);

			g.SetFont(DarkTheme.sDarkTheme.mSmallFont);
			g.DrawString("Lap Input Recording", mRecordLapCombo.mX, mRecordLapCombo.mY - 20);
		}
	}
}
